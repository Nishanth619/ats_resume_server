import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_service.dart';
import '../../../providers/resume_provider.dart';
import '../../../providers/auth_provider.dart';

class LinkedInImportBanner extends ConsumerStatefulWidget {
  final String resumeId;
  final VoidCallback onImported;
  const LinkedInImportBanner({
    super.key,
    required this.resumeId,
    required this.onImported,
  });

  @override
  ConsumerState<LinkedInImportBanner> createState() => _LIBannerState();
}

class _LIBannerState extends ConsumerState<LinkedInImportBanner> {
  bool _expanded = false;
  bool _loading = false;
  final _urlCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final url = _urlCtrl.text.trim();
    if (!url.contains('linkedin.com/in/')) {
      setState(() => _error = 'Enter a valid LinkedIn URL (linkedin.com/in/yourname)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ref.read(aiServiceProvider).importFromLinkedIn(url);
      if (data.isEmpty) throw Exception('Could not extract profile data. Make sure the profile is public.');
      
      // ignore: unused_local_variable
      final uid = ref.read(authStateProvider).value?.uid ?? '';
      final notifier = ref.read(resumeNotifierProvider(widget.resumeId).notifier);
      
      // Map LinkedIn data to resume sections
      if (data['name'] != null || data['summary'] != null) {
        notifier.updateSection('personal', {
          'name': data['name'] ?? '',
          'summary': data['summary'] ?? '',
          'linkedin': url,
          'headline': data['headline'] ?? '',
        });
      }
      if (data['experience'] != null) {
        notifier.updateSection(
            'experience',
            List<Map<String, dynamic>>.from((data['experience'] as List).map((e) => {
                  'title': e['title'] ?? '',
                  'company': e['company'] ?? '',
                  'dates': e['dates'] ?? '',
                  'location': e['location'] ?? '',
                  'description': e['description'] ?? '',
                })));
      }
      if (data['education'] != null) {
        notifier.updateSection(
            'education',
            List<Map<String, dynamic>>.from((data['education'] as List).map((e) => {
                  'degree': e['degree'] ?? '',
                  'institution': e['institution'] ?? '',
                  'year': e['year'] ?? '',
                })));
      }
      if (data['skills'] != null) {
        notifier.updateSection('skills', List<String>.from(data['skills'] as List));
      }
      
      await notifier.save();
      widget.onImported();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0077B5), Color(0xFF005E92)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0077B5).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: _expanded ? _buildForm() : _buildPrompt(),
    );
  }

  Widget _buildPrompt() => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.business, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Import from LinkedIn',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const Text('Pre-fill your resume in seconds',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
          TextButton(
            onPressed: () => setState(() => _expanded = true),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Import'),
          ),
        ]),
      );

  Widget _buildForm() => Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.business, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Import from LinkedIn',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: () => setState(() => _expanded = false)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'https://linkedin.com/in/yourname',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              errorText: _error,
              errorStyle: const TextStyle(color: Colors.yellowAccent),
            ),
          ),
          const SizedBox(height: 10),
          _loading
              ? const Center(
                  child: SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: _import,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0077B5)),
                  child: const Text('Import & Pre-fill Resume')),
          const SizedBox(height: 6),
          const Text('Your LinkedIn profile must be set to Public.',
              style: TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      );
}
