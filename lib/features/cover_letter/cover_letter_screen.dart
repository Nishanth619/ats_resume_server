import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/ai_service.dart';
import '../../services/usage_tracker.dart';
import '../../services/admob_service.dart';
import '../../services/subscription_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/pro_upgrade_sheet.dart';

// ─── Screen state machine ─────────────────────────────────────────────────────
enum _ScreenState { idle, generating, done, error }

class CoverLetterScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const CoverLetterScreen({super.key, required this.resumeId});

  @override
  ConsumerState<CoverLetterScreen> createState() => _CLState();
}

class _CLState extends ConsumerState<CoverLetterScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _companyCtrl = TextEditingController();
  final _jdCtrl      = TextEditingController();
  final _letterCtrl  = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  // ── State ────────────────────────────────────────────────────────────────────
  _ScreenState _state        = _ScreenState.idle;
  String?      _errorMsg;
  String?      _savedDocId;
  bool         _hasUnsaved   = false;
  int          _wordCount    = 0;
  String       _engineBadge  = '';

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: 1500))
      ..repeat();
    _letterCtrl.addListener(_onLetterEdited);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _companyCtrl.dispose();
    _jdCtrl.dispose();
    _letterCtrl.dispose();
    super.dispose();
  }

  void _onLetterEdited() {
    final words = _letterCtrl.text.trim().isEmpty
        ? 0
        : _letterCtrl.text.trim().split(RegExp(r'\s+')).length;
    if (words != _wordCount) setState(() => _wordCount = words);
    if (!_hasUnsaved && _savedDocId != null) {
      setState(() => _hasUnsaved = true);
    }
  }

  // ── Generate ─────────────────────────────────────────────────────────────────
  Future<bool> _checkUsage() async {
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return true;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return false;

    final count = await UsageTracker.getUsageCount(AiFeature.coverLetter, uid);
    if (count >= UsageTracker.getLimit(AiFeature.coverLetter)) {
      if (mounted) showProUpgradeSheet(context, ref);
      return false;
    }
    return true;
  }

  Future<void> _showAd() async {
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return;
    final adSvc = ref.read(adServiceProvider);
    await adSvc.loadRewardedAd();
    await adSvc.showRewardedAdAndWait(
      onAdWatched: () {},
      onAdFailed: () {},
    );
  }

  Future<void> _incrementUsage() async {
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      await UsageTracker.incrementUsage(AiFeature.coverLetter, uid);
    }
  }

  Future<void> _generate() async {
    // Double-tap guard
    if (_state == _ScreenState.generating) return;
    if (!_formKey.currentState!.validate()) return;

    final canUse = await _checkUsage();
    if (!canUse) return;

    FocusScope.of(context).unfocus();

    // Show ad BEFORE API call
    await _showAd();

    setState(() {
      _state       = _ScreenState.generating;
      _errorMsg    = null;
      _savedDocId  = null;
      _hasUnsaved  = false;
      _engineBadge = '';
    });

    try {
      // Wait for resume data robustly
      final resume = await fetchResumeRobustly(ref, widget.resumeId);

      final uid  = ref.read(authStateProvider).value?.uid;
      if (uid == null) {
        throw CoverLetterValidationException('You are not signed in.');
      }

      // Build resume text
      final p        = Map<String, dynamic>.from(resume.sections['personal'] ?? {});
      final expList  = resume.sections['experience'] as List? ?? [];
      final skillList= resume.sections['skills'] as List? ?? [];
      final buf      = StringBuffer();
      if ((p['summary'] as String?)?.isNotEmpty == true) buf.writeln(p['summary']);
      for (final e in expList) {
        final exp = e as Map<String, dynamic>;
        buf.writeln('${exp['title'] ?? ''} at ${exp['company'] ?? ''}: ${exp['description'] ?? ''}');
      }
      if (skillList.isNotEmpty) buf.writeln('Skills: ${skillList.join(', ')}');

      final result = await ref.read(aiServiceProvider).generateCoverLetter(
        resumeText: buf.toString().trim(),
        company:    _companyCtrl.text.trim(),
        name:       (p['name'] as String?)?.isNotEmpty == true ? p['name'] as String : 'Applicant',
        jd:         _jdCtrl.text.trim().isEmpty ? null : _jdCtrl.text.trim(),
      );

      // Increment usage count AFTER successful call
      await _incrementUsage();

      _letterCtrl.text = result.letter;
      setState(() {
        _state       = _ScreenState.done;
        _wordCount   = result.wordCount;
        _engineBadge = result.engine;
      });

      // Save to Firestore (non-blocking)
      _saveToFirestore(uid, result);

    } on CoverLetterValidationException catch (e) {
      setState(() { _state = _ScreenState.error; _errorMsg = e.message; });
    } on CoverLetterTimeoutException catch (e) {
      setState(() { _state = _ScreenState.error; _errorMsg = e.message; });
    } on CoverLetterNetworkException catch (e) {
      setState(() { _state = _ScreenState.error; _errorMsg = e.message; });
    } on CoverLetterServerException catch (e) {
      setState(() { _state = _ScreenState.error; _errorMsg = e.message; });
    } catch (e) {
      setState(() {
        _state    = _ScreenState.error;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveToFirestore(String uid, CoverLetterResult result) async {
    try {
      final docId = await ref.read(firestoreServiceProvider).saveCoverLetter(
        uid:       uid,
        letter:    result.letter,
        company:   _companyCtrl.text.trim(),
        engine:    result.engine,
        wordCount: result.wordCount,
      );
      if (mounted) setState(() { _savedDocId = docId; _hasUnsaved = false; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not auto-save — tap Save to retry'),
        backgroundColor: AppColors.scoreOrange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Save',
          textColor: Colors.white,
          onPressed: _manualSave,
        ),
      ));
    }
  }

  Future<void> _manualSave() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _letterCtrl.text.trim().isEmpty) return;
    try {
      if (_savedDocId != null && _hasUnsaved) {
        await ref.read(firestoreServiceProvider).updateCoverLetter(
          uid: uid, docId: _savedDocId!, letter: _letterCtrl.text);
      } else if (_savedDocId == null) {
        final docId = await ref.read(firestoreServiceProvider).saveCoverLetter(
          uid:       uid,
          letter:    _letterCtrl.text,
          company:   _companyCtrl.text.trim(),
          engine:    'manual',
          wordCount: _wordCount,
        );
        setState(() => _savedDocId = docId);
      }
      if (mounted) {
        setState(() => _hasUnsaved = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _letterCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📋 Copied to clipboard'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  void _share() {
    Share.share(
      _letterCtrl.text,
      subject: 'Cover Letter — ${_companyCtrl.text}',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: GradientAppBar(
        title: 'Cover Letter Builder',
        actions: [
          if (_state == _ScreenState.done && _hasUnsaved)
            TextButton.icon(
              onPressed: _manualSave,
              icon: Icon(Icons.save_outlined, color: AppColors.accentGold, size: 18),
              label: Text('Save', style: TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.w700)),
            ),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header card ────────────────────────────────────────────────
              GlassCard(
                showGlow: true,
                glowColor: AppColors.accent,
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text('✉️', style: TextStyle(fontSize: 24))),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Cover Letter',
                              style: TextStyle(color: context.appColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Generated in seconds, tailored to the role',
                              style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // ── Input card ─────────────────────────────────────────────────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                        title: 'Job Details',
                        subtitle: 'Tell the AI where you\'re applying'),
                    SizedBox(height: 20),

                    // Company field with validation
                    TextFormField(
                      controller: _companyCtrl,
                      enabled: _state != _ScreenState.generating,
                      style: TextStyle(color: context.appColors.textPrimary, fontSize: 15),
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: 'Company Name *',
                        counterText: '',
                        prefixIcon: Icon(Icons.business_outlined, size: 20, color: context.appColors.textMuted),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().length < 2) return 'Enter the company name';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // JD field with live character counter
                    TextFormField(
                      controller: _jdCtrl,
                      enabled: _state != _ScreenState.generating,
                      maxLines: 5,
                      maxLength: 5000,
                      style: TextStyle(color: context.appColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Job Description (optional but recommended)',
                        alignLabelWithHint: true,
                        counterStyle: TextStyle(color: context.appColors.textMuted, fontSize: 10),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.description_outlined, size: 20, color: context.appColors.textMuted),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Generate button — disabled while loading (double-tap guard)
                    GradientButton(
                      label: _state == _ScreenState.generating
                          ? 'Generating…'
                          : _state == _ScreenState.done
                              ? 'Regenerate ✨'
                              : 'Generate with AI ✨',
                      onPressed: _state == _ScreenState.generating ? null : _generate,
                      isLoading: _state == _ScreenState.generating,
                      gradient: AppColors.accentGradient,
                    ),
                  ],
                ),
              ),

              // ── Error banner ────────────────────────────────────────────────
              if (_state == _ScreenState.error && _errorMsg != null) ...[
                SizedBox(height: 16),
                _ErrorBanner(message: _errorMsg!, onRetry: _generate),
              ],

              // ── Result card ─────────────────────────────────────────────────
              if (_state == _ScreenState.done && _letterCtrl.text.isNotEmpty) ...[
                SizedBox(height: 20),
                GlassCard(
                  showGlow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header row with word count, engine badge, actions
                      Row(
                        children: [
                          Text('Your Cover Letter',
                              style: TextStyle(color: context.appColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$_wordCount words',
                                style: TextStyle(color: context.appColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                          if (_engineBadge.isNotEmpty) ...[
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_engineBadge,
                                  style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (_savedDocId != null && !_hasUnsaved) ...[
                            SizedBox(width: 6),
                            Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.scoreGreen),
                          ],
                          Spacer(),
                          // Action icons
                          if (_hasUnsaved)
                            IconButton(
                              icon: Icon(Icons.save_outlined, size: 18, color: AppColors.accentGold),
                              tooltip: 'Save edits',
                              onPressed: _manualSave,
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            icon: Icon(Icons.copy_outlined, size: 18, color: context.appColors.textSecondary),
                            tooltip: 'Copy to clipboard',
                            onPressed: _copy,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(Icons.share_outlined, size: 18, color: context.appColors.textSecondary),
                            tooltip: 'Share',
                            onPressed: _share,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Editable letter area
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.appColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.appColors.border),
                        ),
                        child: TextField(
                          controller: _letterCtrl,
                          maxLines: null,
                          style: TextStyle(
                              color: context.appColors.textPrimary, fontSize: 14, height: 1.75),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Download button
                      GradientButton(
                        label: 'Download FREE — Watch Short Ad',
                        onPressed: () => context.push('/download/${widget.resumeId}'),
                        icon: Icon(Icons.download_rounded, color: Colors.white, size: 18),
                        gradient: AppColors.goldGradient,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error Banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Pick icon based on error type hint in message
    IconData icon = Icons.error_outline_rounded;
    if (message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('connection')) {
      icon = Icons.wifi_off_rounded;
    } else if (message.toLowerCase().contains('timeout') ||
               message.toLowerCase().contains('long')) {
      icon = Icons.timer_off_outlined;
    } else if (message.toLowerCase().contains('unavailable')) {
      icon = Icons.cloud_off_outlined;
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.error, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: TextStyle(color: context.appColors.textPrimary, fontSize: 13, height: 1.5)),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Text('Try Again',
                        style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
