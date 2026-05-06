import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

List<Map<String, dynamic>> kTemplates = [
  {'id': 'classic', 'name': 'Classic', 'premium': false, 'ats': 98, 'emoji': '📋', 'desc': 'Timeless & trusted',
    'gradient': [0xFF475569, 0xFF334155]},
  {'id': 'modern', 'name': 'Modern', 'premium': false, 'ats': 97, 'emoji': '⚡', 'desc': 'Clean & contemporary',
    'gradient': [0xFF6366F1, 0xFF4F46E5]},
  {'id': 'clean', 'name': 'Clean', 'premium': false, 'ats': 99, 'emoji': '✨', 'desc': 'Minimal & elegant',
    'gradient': [0xFF059669, 0xFF047857]},
  {'id': 'professional', 'name': 'Professional', 'premium': false, 'ats': 96, 'emoji': '💼', 'desc': 'Corporate ready',
    'gradient': [0xFF2563EB, 0xFF1D4ED8]},
  {'id': 'minimal', 'name': 'Minimal', 'premium': false, 'ats': 98, 'emoji': '🎯', 'desc': 'Less is more',
    'gradient': [0xFF374151, 0xFF1F2937]},
  {'id': 'executive', 'name': 'Executive', 'premium': false, 'ats': 97, 'emoji': '👔', 'desc': 'Senior-level impact',
    'gradient': [0xFF7C3AED, 0xFF6D28D9]},
  {'id': 'tech', 'name': 'Tech', 'premium': false, 'ats': 96, 'emoji': '💻', 'desc': 'Built for engineers',
    'gradient': [0xFF0369A1, 0xFF075985]},
  {'id': 'creative_safe', 'name': 'Creative', 'premium': false, 'ats': 95, 'emoji': '🎨', 'desc': 'Stands out safely',
    'gradient': [0xFFEA580C, 0xFFC2410C]},
  {'id': 'academic', 'name': 'Academic', 'premium': false, 'ats': 98, 'emoji': '🎓', 'desc': 'Research & academia',
    'gradient': [0xFF166534, 0xFF14532D]},
  {'id': 'simple', 'name': 'Simple', 'premium': false, 'ats': 99, 'emoji': '📄', 'desc': 'Always gets the job done',
    'gradient': [0xFF374151, 0xFF111827]},
  {'id': 'pro_elite', 'name': 'Elite', 'premium': true, 'ats': 99, 'emoji': '👑', 'desc': 'Top 1% candidates',
    'gradient': [0xFF7C3AED, 0xFF06B6D4]},
  {'id': 'pro_bold', 'name': 'Bold', 'premium': true, 'ats': 97, 'emoji': '🔥', 'desc': 'Make an entrance',
    'gradient': [0xFFDC2626, 0xFF9F1239]},
  {'id': 'pro_ivy', 'name': 'Ivy League', 'premium': true, 'ats': 98, 'emoji': '🏛️', 'desc': 'Prestige & authority',
    'gradient': [0xFF1E3A5F, 0xFF0F2942]},
  {'id': 'pro_startup', 'name': 'Startup', 'premium': true, 'ats': 96, 'emoji': '🚀', 'desc': 'Built for builders',
    'gradient': [0xFF7C3AED, 0xFF4F46E5]},
  {'id': 'pro_global', 'name': 'Global', 'premium': true, 'ats': 97, 'emoji': '🌍', 'desc': 'International appeal',
    'gradient': [0xFF0F766E, 0xFF134E4A]},
];

class TemplatePickerScreen extends ConsumerStatefulWidget {
  const TemplatePickerScreen({super.key});
  @override
  ConsumerState<TemplatePickerScreen> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends ConsumerState<TemplatePickerScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedId;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _freeTemplates =>
      kTemplates.where((t) => t['premium'] == false).toList();
  List<Map<String, dynamic>> get _proTemplates =>
      kTemplates.where((t) => t['premium'] == true).toList();

  void _select(Map<String, dynamic> t, bool isPro) {
    if (t['premium'] == true && !isPro) {
      _showProSheet();
      return;
    }
    _showTemplatePreview(t);
  }

  void _showProSheet() {
    final user = ref.read(userDataProvider).value;
    final uid = user?.uid ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ProPaywallSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider).value;
    final isProSub = ref.watch(subscriptionProvider);
    // Pro if Firestore plan == 'pro' OR if subscriptionProvider is true
    final isPro = user?.plan == 'pro' || isProSub;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: context.appColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: context.appColors.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: ShaderMask(
              shaderCallback: (b) => context.appColors.primaryGradient.createShader(b),
              child: Text('Choose Template',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            actions: [
              if (_selectedId != null)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/editor/new?template=$_selectedId'),
                    child: GradientBadge(text: 'Use This →'),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(50),
              child: Container(
                margin: EdgeInsets.fromLTRB(20, 0, 20, 12),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appColors.border),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: context.appColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.appColors.textSecondary,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: '🎁  Free (10)'),
                    Tab(text: '👑  Pro (5)'),
                  ],
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _TemplateGrid(
                    templates: _freeTemplates,
                    selectedId: _selectedId,
                    isPro: isPro,
                    onSelect: _select),
                _TemplateGrid(
                    templates: _proTemplates,
                    selectedId: _selectedId,
                    isPro: isPro,
                    onSelect: _select),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplatePreview(Map<String, dynamic> t) {
    final gradColors = (t['gradient'] as List).map((c) => Color(c as int)).toList();
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(color: context.appColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => LinearGradient(colors: gradColors).createShader(b),
                      child: Text(t['name'], style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(width: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.scoreGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.scoreGreen.withValues(alpha: 0.3)),
                      ),
                      child: Text('ATS ${t['ats']}%', style: TextStyle(color: AppColors.scoreGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Spacer(),
                    Text(t['desc'], style: TextStyle(color: context.appColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 420),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 40, offset: Offset(0, 12))],
                        ),
                        child: AspectRatio(
                          aspectRatio: 1 / 1.414,
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.all(20),
                            child: _FullTemplatePreview(templateId: t['id'], color: gradColors[0]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.appColors.textSecondary,
                          side: BorderSide(color: context.appColors.border),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Back'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradColors),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: gradColors[0].withValues(alpha: 0.4), blurRadius: 16, offset: Offset(0, 4))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedId = t['id']);
                            context.push('/editor/new?template=${t['id']}');
                          },
                          icon: Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                          label: Text('Use This Template',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  final List<Map<String, dynamic>> templates;
  final String? selectedId;
  final bool isPro;
  final void Function(Map<String, dynamic>, bool) onSelect;

  const _TemplateGrid({
    required this.templates,
    required this.selectedId,
    required this.isPro,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78),
      itemCount: templates.length,
      itemBuilder: (_, i) {
        final t = templates[i];
        final isSelected = selectedId == t['id'];
        final isLocked = t['premium'] == true && !isPro;
        final gradColors = (t['gradient'] as List)
            .map((c) => Color(c as int))
            .toList();

        return GestureDetector(
          onTap: () => onSelect(t, isPro),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primaryLight : context.appColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: [
                // Preview area
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
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(17)),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          child: Center(
                            child: _MiniResumePreview(templateId: t['id'], color: gradColors[0]),
                          ),
                        ),
                      ),
                      // Lock overlay
                      if (isLocked)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(17)),
                          ),
                          child: Center(
                            child: Icon(Icons.lock_rounded,
                                color: Colors.white, size: 28),
                          ),
                        ),
                      // Selected checkmark
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
                            child: Icon(Icons.check_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      // ATS badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ATS ${t['ats']}%',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Info row
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'],
                                style: TextStyle(
                                    color: context.appColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            Text(t['desc'],
                                style: TextStyle(
                                    color: context.appColors.textMuted,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                      if (t['premium'] == true)
                        GradientBadge(
                            text: 'PRO', gradient: AppColors.goldGradient)
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.scoreGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.scoreGreen.withValues(alpha: 0.3)),
                          ),
                          child: Text('FREE',
                              style: TextStyle(
                                  color: AppColors.scoreGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
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
  final String templateId;
  final Color color;
  const _MiniResumePreview({required this.templateId, required this.color});

  @override
  Widget build(BuildContext context) {
    // Determine layout based on template type
    bool isModern = templateId == 'modern' || templateId == 'tech' || templateId == 'pro_startup';
    bool isMinimal = templateId == 'minimal' || templateId == 'clean' || templateId == 'simple';
    
    return AspectRatio(
      aspectRatio: 1 / 1.414, // A4 ratio
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        padding: EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            if (isModern) ...[
              Container(
                height: 12,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
                margin: EdgeInsets.only(bottom: 4),
              ),
              _line(Colors.black87, 0.6, 3),
              SizedBox(height: 2),
              _line(Colors.black38, 0.4, 2),
            ] else if (isMinimal) ...[
              Center(child: _line(Colors.black87, 0.5, 4)),
              SizedBox(height: 2),
              Center(child: _line(Colors.black38, 0.8, 2)),
            ] else ...[
              // Classic
              _line(color, 0.5, 4),
              SizedBox(height: 2),
              _line(Colors.black38, 1.0, 2),
            ],
            
            SizedBox(height: 6),
            
            // Sections
            _section(isModern ? color : Colors.black87, 0.3),
            _textBlock(),
            SizedBox(height: 4),
            _section(isModern ? color : Colors.black87, 0.4),
            _textBlock(),
            SizedBox(height: 4),
            _section(isModern ? color : Colors.black87, 0.3),
            _textBlock(),
          ],
        ),
      ),
    );
  }

  Widget _section(Color c, double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(c, w, 2.5),
        SizedBox(height: 2),
        if (templateId == 'classic')
          Container(height: 0.5, color: c, margin: EdgeInsets.only(bottom: 2)),
      ],
    );
  }

  Widget _textBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(Colors.black54, 0.9, 1.5),
        SizedBox(height: 1.5),
        _line(Colors.black54, 0.85, 1.5),
        SizedBox(height: 1.5),
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

// ── Full-detail template preview (for the modal) ─────────────────────────────
class _FullTemplatePreview extends StatelessWidget {
  final String templateId;
  final Color color;
  const _FullTemplatePreview({required this.templateId, required this.color});

  @override
  Widget build(BuildContext context) {
    final isModern = templateId == 'modern' || templateId == 'tech' || templateId == 'pro_startup' || templateId == 'pro_bold';
    final isMinimal = templateId == 'minimal' || templateId == 'clean' || templateId == 'simple' || templateId == 'academic';
    final isExec = templateId == 'executive' || templateId == 'pro_elite' || templateId == 'pro_ivy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        if (isModern) _modernHeader() else if (isMinimal) _minimalHeader() else _classicHeader(),
        SizedBox(height: 10),
        // Summary
        _sectionLabel('PROFESSIONAL SUMMARY', isModern, isExec),
        _textLines(3, 0.95),
        SizedBox(height: 8),
        // Experience
        _sectionLabel('EXPERIENCE', isModern, isExec),
        _jobEntry('Senior Product Designer', 'Google Inc.', '2022 – Present'),
        _jobEntry('UX Designer', 'Meta Platforms', '2020 – 2022'),
        SizedBox(height: 8),
        // Education
        _sectionLabel('EDUCATION', isModern, isExec),
        _eduEntry('B.Sc Computer Science', 'Stanford University', '2020'),
        SizedBox(height: 8),
        // Skills
        _sectionLabel('SKILLS', isModern, isExec),
        _skillChips(isModern),
      ],
    );
  }

  Widget _classicHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(color, 0.55, 5),
      SizedBox(height: 3),
      _line(Colors.black45, 0.4, 2.5),
      SizedBox(height: 3),
      _line(Colors.black26, 0.85, 1),
    ],
  );

  Widget _modernHeader() => Container(
    padding: EdgeInsets.all(6),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(Colors.white, 0.5, 5),
        SizedBox(height: 3),
        _line(Colors.white70, 0.35, 2.5),
        SizedBox(height: 3),
        _line(Colors.white54, 0.7, 1.5),
      ],
    ),
  );

  Widget _minimalHeader() => Center(
    child: Column(
      children: [
        _line(Colors.black87, 0.45, 5),
        SizedBox(height: 3),
        _line(Colors.black45, 0.6, 2),
        SizedBox(height: 3),
        _line(Colors.black26, 0.8, 1),
      ],
    ),
  );

  Widget _sectionLabel(String label, bool isModern, bool isExec) {
    if (isModern) {
      return Container(
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: 5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isExec ? color : Colors.black87, fontSize: 5.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          Container(height: 0.5, color: isExec ? color : Colors.black26, margin: EdgeInsets.only(top: 1)),
        ],
      ),
    );
  }

  Widget _textLines(int count, double w) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(count, (i) => Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: _line(Colors.black26, i == count - 1 ? w * 0.7 : w, 1.5),
    )),
  );

  Widget _jobEntry(String title, String company, String dates) => Padding(
    padding: EdgeInsets.only(bottom: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 5.5, fontWeight: FontWeight.bold, color: Colors.black87))),
            Text(dates, style: TextStyle(fontSize: 4.5, color: Colors.black45)),
          ],
        ),
        SizedBox(height: 1),
        Text(company, style: TextStyle(fontSize: 5, color: color, fontStyle: FontStyle.italic)),
        SizedBox(height: 2),
        _line(Colors.black26, 0.9, 1.5),
        SizedBox(height: 1.5),
        _line(Colors.black26, 0.75, 1.5),
      ],
    ),
  );

  Widget _eduEntry(String degree, String school, String year) => Padding(
    padding: EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(degree, style: TextStyle(fontSize: 5.5, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(school, style: TextStyle(fontSize: 5, color: Colors.black54)),
          ],
        )),
        Text(year, style: TextStyle(fontSize: 4.5, color: Colors.black45)),
      ],
    ),
  );

  Widget _skillChips(bool isModern) => Wrap(
    spacing: 3,
    runSpacing: 3,
    children: ['Flutter', 'Dart', 'Firebase', 'UI/UX', 'Figma'].map((s) => Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isModern ? color.withAlpha(25) : Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: isModern ? color.withAlpha(80) : Colors.black26, width: 0.5),
      ),
      child: Text(s, style: TextStyle(fontSize: 5, color: isModern ? color : Colors.black54)),
    )).toList(),
  );

  Widget _line(Color c, double w, double h) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: w,
    child: Container(
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h / 2)),
    ),
  );
}

// ─── Pro Paywall Bottom Sheet ─────────────────────────────────────────────
class _ProPaywallSheet extends ConsumerStatefulWidget {
  final String uid;
  const _ProPaywallSheet({required this.uid});

  @override
  ConsumerState<_ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends ConsumerState<_ProPaywallSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _upgrade() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      final success = await ref
          .read(subscriptionProvider.notifier)
          .purchasePro(uid: widget.uid);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Welcome to Pro! All templates unlocked.'),
            backgroundColor: AppColors.scoreGreen,
          ),
        );
      } else {
        setState(() => _error = 'Purchase could not be completed. Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() { _loading = true; _error = null; });
    await ref.read(subscriptionProvider.notifier).restorePurchases(uid: widget.uid);
    if (!mounted) return;
    setState(() => _loading = false);
    final isPro = ref.read(subscriptionProvider);
    if (isPro) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Pro access restored!')),
      );
    } else {
      setState(() => _error = 'No active Pro subscription found.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Crown + title
          const Text('👑', textAlign: TextAlign.center, style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text(
            'ATS.ai Pro',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Designed for candidates who demand the best.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Features
          ...[
            ('👑', '5 Elite Pro Templates', 'FAANG, Fortune 500 & Executive designs'),
            ('🤖', 'Unlimited ATS Checks', 'Free users get 3/day'),
            ('✨', 'Priority AI Generation', 'Faster, higher-quality responses'),
            ('📄', 'Unlimited Resumes', 'Free users limited to 3'),
            ('💼', 'DOCX Export', 'Word-compatible export for recruiters'),
          ].map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(f.$1, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$2, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13,
                      )),
                      Text(f.$3, style: TextStyle(
                        color: context.appColors.textMuted, fontSize: 11,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          )),

          const SizedBox(height: 20),

          // Price badge
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Text(
              '₹299 / month  •  Cancel anytime',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.scoreRed, fontSize: 12),
              ),
            ),

          // Upgrade button
          GradientButton(
            label: _loading ? 'Processing…' : 'Upgrade to Pro',
            onPressed: _loading ? () {} : _upgrade,
            gradient: AppColors.goldGradient,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.star_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),

          // Restore
          TextButton(
            onPressed: _loading ? null : _restore,
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}

