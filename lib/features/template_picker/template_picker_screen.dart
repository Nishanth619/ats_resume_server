import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/resume_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';

class TemplatePickerScreen extends ConsumerStatefulWidget {
  const TemplatePickerScreen({super.key});

  @override
  ConsumerState<TemplatePickerScreen> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends ConsumerState<TemplatePickerScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedId;
  late TabController _tabCtrl;
  bool _isPreviewOpen = false;

  static final List<ResumeTemplate> _freeTemplates = resumeTemplatesForTier(
    TemplateTier.free,
  ).toList();
  static final List<ResumeTemplate> _proTemplates = resumeTemplatesForTier(
    TemplateTier.pro,
  ).toList();
  static final List<_TemplateTab> _tabs = [
    _TemplateTab(label: 'Free', templates: _freeTemplates),
    _TemplateTab(label: 'Pro', templates: _proTemplates),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool _isPro(AsyncValue<dynamic> userAsync, bool subProvider) {
    return userAsync.value?.plan == 'pro' || subProvider;
  }

  void _onTemplateTap(ResumeTemplate t, bool isPro) {
    if (t.isPremium && !isPro) {
      _showProSheet();
      return;
    }
    // Optimistically mark as selected so the highlight moves immediately
    setState(() => _selectedId = t.id);
    _showTemplatePreview(t);
  }

  void _showProSheet() {
    final uid = ref.read(userDataProvider).value?.uid ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProPaywallSheet(uid: uid),
    );
  }

  void _showTemplatePreview(ResumeTemplate t) {
    final gradColors = t.gradientColors.map((c) => Color(c)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.6,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          LinearGradient(colors: gradColors).createShader(b),
                      child: Text(
                        t.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AtsBadge(score: t.atsScore),
                    const Spacer(),
                    Text(
                      t.description,
                      style: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 40,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: AspectRatio(
                          aspectRatio: 1 / 1.414,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: _FullTemplatePreview(
                              template: t,
                              accentColor: gradColors[0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.appColors.textSecondary,
                          side: BorderSide(color: context.appColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradColors),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: gradColors[0].withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedId = t.id);
                            context.push('/editor/new?template=${t.id}');
                          },
                          icon: const Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Use This Template',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _isPreviewOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDataProvider);
    final isProSub = ref.watch(subscriptionProvider);
    final isPro = _isPro(userAsync, isProSub);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: context.appColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: context.appColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: ShaderMask(
              shaderCallback: (b) =>
                  context.appColors.primaryGradient.createShader(b),
              child: const Text(
                'Choose Template',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            actions: [
              if (_selectedId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/editor/new?template=$_selectedId'),
                    child: const GradientBadge(text: 'Use This ->'),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appColors.border),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.appColors.textPrimary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: [
                    for (final tab in _tabs)
                      Tab(text: '${tab.label} (${tab.templates.length})'),
                  ],
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                for (final tab in _tabs)
                  _TemplateGrid(
                    templates: tab.templates,
                    selectedId: _selectedId,
                    isPro: isPro,
                    onSelect: _onTemplateTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateTab {
  final String label;
  final List<ResumeTemplate> templates;

  const _TemplateTab({required this.label, required this.templates});
}

class _AtsBadge extends StatelessWidget {
  final int score;

  const _AtsBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.scoreGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.scoreGreen.withValues(alpha: 0.3)),
      ),
      child: Text(
        'ATS $score%',
        style: const TextStyle(
          color: AppColors.scoreGreen,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  final List<ResumeTemplate> templates;
  final String? selectedId;
  final bool isPro;
  final void Function(ResumeTemplate, bool) onSelect;

  const _TemplateGrid({
    required this.templates,
    required this.selectedId,
    required this.isPro,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Center(
        child: Text(
          'No templates available',
          style: TextStyle(color: context.appColors.textMuted),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: templates.length,
      itemBuilder: (_, i) {
        final t = templates[i];
        final isSelected = selectedId == t.id;
        final isLocked = t.isPremium && !isPro;
        final gradColors = t.gradientColors.map((c) => Color(c)).toList();

        return GestureDetector(
          onTap: () => onSelect(t, isPro),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryLight
                    : context.appColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : AppColors.primaryDark.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(17),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Center(
                            child: _MiniResumePreview(
                              layout: t.layout,
                              accentColor: gradColors[0],
                            ),
                          ),
                        ),
                      ),
                      if (isLocked)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(17),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: context.appColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ATS ${t.atsScore}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: TextStyle(
                                color: context.appColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              t.description,
                              style: TextStyle(
                                color: context.appColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (t.isPremium)
                        GradientBadge(
                          text: 'PRO',
                          gradient: AppColors.goldGradient,
                        )
                      else
                        Builder(
                          builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final freeColor = isDark
                                ? const Color(0xFF34D399) // brighter in dark
                                : const Color(0xFF047857); // darker for contrast in light
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: freeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: freeColor.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  color: freeColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniResumePreview extends StatelessWidget {
  final TemplateLayout layout;
  final Color accentColor;

  const _MiniResumePreview({required this.layout, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1.414,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 6),
            _section(accentColor, 0.3),
            _textBlock(),
            const SizedBox(height: 4),
            _section(accentColor, 0.4),
            _textBlock(),
            const SizedBox(height: 4),
            _section(accentColor, 0.3),
            _textBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    switch (layout) {
      case TemplateLayout.modern:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(1),
              ),
              margin: const EdgeInsets.only(bottom: 4),
            ),
            _line(Colors.black87, 0.6, 3),
            const SizedBox(height: 2),
            _line(Colors.black38, 0.4, 2),
          ],
        );
      case TemplateLayout.minimal:
        return Column(
          children: [
            Center(child: _line(Colors.black87, 0.5, 4)),
            const SizedBox(height: 2),
            Center(child: _line(Colors.black38, 0.8, 2)),
          ],
        );
      case TemplateLayout.classic:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(accentColor, 0.5, 4),
            const SizedBox(height: 2),
            _line(Colors.black38, 1.0, 2),
          ],
        );
    }
  }

  Widget _section(Color c, double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(c, w, 2.5),
        const SizedBox(height: 2),
        if (layout == TemplateLayout.classic)
          Container(
            height: 0.5,
            color: c,
            margin: const EdgeInsets.only(bottom: 2),
          ),
      ],
    );
  }

  Widget _textBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(Colors.black54, 0.9, 1.5),
        const SizedBox(height: 1.5),
        _line(Colors.black54, 0.85, 1.5),
        const SizedBox(height: 1.5),
        _line(Colors.black54, 0.6, 1.5),
      ],
    );
  }

  Widget _line(Color c, double w, double h) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: w,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(h / 2),
        ),
      ),
    );
  }
}

class _FullTemplatePreview extends StatelessWidget {
  final ResumeTemplate template;
  final Color accentColor;

  const _FullTemplatePreview({
    required this.template,
    required this.accentColor,
  });

  bool get _isModern => template.layout == TemplateLayout.modern;
  bool get _isMinimal => template.layout == TemplateLayout.minimal;
  bool get _isExec =>
      template.id == 'executive' ||
      template.id == 'pro_elite' ||
      template.id == 'pro_ivy';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isModern)
          _modernHeader()
        else if (_isMinimal)
          _minimalHeader()
        else
          _classicHeader(),
        const SizedBox(height: 10),
        _sectionLabel('PROFESSIONAL SUMMARY'),
        _textLines(3, 0.95),
        const SizedBox(height: 8),
        _sectionLabel('EXPERIENCE'),
        _jobEntry('Senior Product Designer', 'Google Inc.', '2022 - Present'),
        _jobEntry('UX Designer', 'Meta Platforms', '2020 - 2022'),
        const SizedBox(height: 8),
        _sectionLabel('EDUCATION'),
        _eduEntry('B.Sc Computer Science', 'Stanford University', '2020'),
        const SizedBox(height: 8),
        _sectionLabel('SKILLS'),
        _skillChips(),
      ],
    );
  }

  Widget _classicHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(accentColor, 0.55, 5),
      const SizedBox(height: 3),
      _line(Colors.black45, 0.4, 2.5),
      const SizedBox(height: 3),
      _line(Colors.black26, 0.85, 1),
    ],
  );

  Widget _modernHeader() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: accentColor,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(Colors.white, 0.5, 5),
        const SizedBox(height: 3),
        _line(Colors.white70, 0.35, 2.5),
        const SizedBox(height: 3),
        _line(Colors.white54, 0.7, 1.5),
      ],
    ),
  );

  Widget _minimalHeader() => Center(
    child: Column(
      children: [
        _line(Colors.black87, 0.45, 5),
        const SizedBox(height: 3),
        _line(Colors.black45, 0.6, 2),
        const SizedBox(height: 3),
        _line(Colors.black26, 0.8, 1),
      ],
    ),
  );

  Widget _sectionLabel(String label) {
    if (_isModern) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _isExec ? accentColor : Colors.black87,
              fontSize: 5.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          Container(
            height: 0.5,
            color: _isExec ? accentColor : Colors.black26,
            margin: const EdgeInsets.only(top: 1),
          ),
        ],
      ),
    );
  }

  Widget _textLines(int count, double w) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(
      count,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _line(Colors.black26, i == count - 1 ? w * 0.7 : w, 1.5),
      ),
    ),
  );

  Widget _jobEntry(String title, String company, String dates) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 5.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              dates,
              style: const TextStyle(fontSize: 4.5, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          company,
          style: TextStyle(
            fontSize: 5,
            color: accentColor,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 2),
        _line(Colors.black26, 0.9, 1.5),
        const SizedBox(height: 1.5),
        _line(Colors.black26, 0.75, 1.5),
      ],
    ),
  );

  Widget _eduEntry(String degree, String school, String year) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                degree,
                style: const TextStyle(
                  fontSize: 5.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                school,
                style: const TextStyle(fontSize: 5, color: Colors.black54),
              ),
            ],
          ),
        ),
        Text(
          year,
          style: const TextStyle(fontSize: 4.5, color: Colors.black45),
        ),
      ],
    ),
  );

  Widget _skillChips() => Wrap(
    spacing: 3,
    runSpacing: 3,
    children: ['Flutter', 'Dart', 'Firebase', 'UI/UX', 'Figma']
        .map(
          (s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _isModern
                  ? accentColor.withAlpha(25)
                  : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: _isModern ? accentColor.withAlpha(80) : Colors.black26,
                width: 0.5,
              ),
            ),
            child: Text(
              s,
              style: TextStyle(
                fontSize: 5,
                color: _isModern ? accentColor : Colors.black54,
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _line(Color c, double w, double h) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: w,
    child: Container(
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(h / 2),
      ),
    ),
  );
}

class _ProPaywallSheet extends ConsumerStatefulWidget {
  final String uid;

  const _ProPaywallSheet({required this.uid});

  @override
  ConsumerState<_ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends ConsumerState<_ProPaywallSheet> {
  bool _loading = false;
  String? _error;

  static const _features = [
    ('PRO', '5 Elite Pro Templates', 'FAANG, Fortune 500 & Executive designs'),
    ('AI', 'Unlimited ATS Checks', 'Free users get 5/day'),
    ('+', 'Unlimited AI Tailoring', 'Free users get 5/day'),
    ('CV', 'Unlimited Cover Letters', 'Free users get 5/day'),
    ('DOC', 'DOCX Word Export', 'Word-compatible export for recruiters'),
  ];

  Future<void> _upgrade() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(subscriptionProvider.notifier)
        .purchasePro(uid: widget.uid);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case PurchaseResult.success:
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Welcome to Pro! All features unlocked.'),
            backgroundColor: AppColors.scoreGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.billingUnavailable:
        setState(() => _error =
            'Billing is not configured yet. Please check back soon.');
      case PurchaseResult.noOfferings:
        setState(() => _error =
            'No subscription plans found. Please try again later.');
      case PurchaseResult.notEntitled:
        setState(() => _error =
            'Purchase complete but entitlement not found. Try restoring.');
      case PurchaseResult.error:
        setState(() => _error = 'Purchase failed. Please try again.');
    }
  }

  Future<void> _restore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(subscriptionProvider.notifier)
        .restorePurchases(uid: widget.uid);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case RestoreResult.restored:
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Pro subscription restored!'),
            backgroundColor: AppColors.scoreGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case RestoreResult.nothingToRestore:
        setState(() => _error = 'No previous purchases found for this account.');
      case RestoreResult.error:
        setState(() => _error = 'Restore failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceAsync = ref.watch(subscriptionPriceProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Crown icon + title
            Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.4),
                      blurRadius: 24, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white, size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ATS.ai Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),

            // Price
            priceAsync.when(
              data: (price) => Text(
                price ?? 'Billing unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: price != null ? AppColors.accentGold : context.appColors.textMuted,
                  fontSize: 16, fontWeight: FontWeight.w700,
                ),
              ),
              loading: () => const Center(
                child: SizedBox(
                  height: 16, width: 100,
                  child: LinearProgressIndicator(
                    color: AppColors.accentGold,
                    backgroundColor: Color(0x1AF59E0B),
                  ),
                ),
              ),
              error: (_, __) => Text(
                'Price unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appColors.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Feature list
            ..._features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          f.$1,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 10, fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontWeight: FontWeight.w700, fontSize: 13,
                            )),
                          Text(f.$3,
                            style: TextStyle(
                              color: context.appColors.textMuted, fontSize: 11,
                            )),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.scoreGreen, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.scoreRed, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Subscribe button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _loading
                  ? null
                  : priceAsync.whenOrNull(data: (p) => p == null ? null : _upgrade),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2,
                      ),
                    )
                  : priceAsync.when(
                      data: (price) => Text(
                        price == null ? 'Billing Unavailable' : 'Subscribe — $price',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16,
                        ),
                      ),
                      loading: () => const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2,
                        ),
                      ),
                      error: (_, __) => const Text('Unavailable',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
            ),
            const SizedBox(height: 10),

            // Restore
            TextButton(
              onPressed: _loading ? null : _restore,
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe later',
                style: TextStyle(color: context.appColors.textMuted),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Subscriptions are managed by Google Play.\nCancel anytime in Play Store.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

