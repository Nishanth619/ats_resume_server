import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

const List<Map<String, dynamic>> kTemplates = [
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
    setState(() => _selectedId = t['id']);
  }

  void _showProSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            const Text('👑', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('Upgrade to Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Unlock elite templates designed for FAANG and Fortune 500 companies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Upgrade Now',
              onPressed: () async {
                final success = await ref.read(subscriptionProvider.notifier).purchasePro();
                if (success) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upgraded to Pro successfully!')),
                  );
                }
              },
              gradient: AppColors.goldGradient,
              icon: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider).value;
    final isPro = user?.plan == 'pro' || ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surfaceDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: ShaderMask(
              shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
              child: const Text('Choose Template',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            actions: [
              if (_selectedId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/editor/new?template=$_selectedId'),
                    child: GradientBadge(text: 'Use This →'),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primaryLight : AppColors.borderDark,
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
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(17)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
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
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(17)),
                          ),
                          child: const Center(
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
                            decoration: const BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      // ATS badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ATS ${t['ats']}%',
                              style: const TextStyle(
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'],
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            Text(t['desc'],
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                      if (t['premium'] == true)
                        GradientBadge(
                            text: 'PRO', gradient: AppColors.goldGradient)
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.scoreGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.scoreGreen.withValues(alpha: 0.3)),
                          ),
                          child: const Text('FREE',
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
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            if (isModern) ...[
              Container(
                height: 12,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
                margin: const EdgeInsets.only(bottom: 4),
              ),
              _line(Colors.black87, 0.6, 3),
              const SizedBox(height: 2),
              _line(Colors.black38, 0.4, 2),
            ] else if (isMinimal) ...[
              Center(child: _line(Colors.black87, 0.5, 4)),
              const SizedBox(height: 2),
              Center(child: _line(Colors.black38, 0.8, 2)),
            ] else ...[
              // Classic
              _line(color, 0.5, 4),
              const SizedBox(height: 2),
              _line(Colors.black38, 1.0, 2),
            ],
            
            const SizedBox(height: 6),
            
            // Sections
            _section(isModern ? color : Colors.black87, 0.3),
            _textBlock(),
            const SizedBox(height: 4),
            _section(isModern ? color : Colors.black87, 0.4),
            _textBlock(),
            const SizedBox(height: 4),
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
        const SizedBox(height: 2),
        if (templateId == 'classic')
          Container(height: 0.5, color: c, margin: const EdgeInsets.only(bottom: 2)),
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
