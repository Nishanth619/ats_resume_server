// lib/models/resume_template.dart

enum TemplateLayout { classic, modern, minimal }

enum TemplateTier { free, pro }

enum TemplateLayoutFamily { classic, modern, minimal }

class ResumeTemplate {
  final String id;
  final String name;
  final TemplateTier tier;
  final int atsScore;
  final String emoji;
  final String description;
  final List<int> gradientColors; // ARGB ints
  final TemplateLayout layout;

  const ResumeTemplate({
    required this.id,
    required this.name,
    required this.tier,
    required this.atsScore,
    required this.emoji,
    required this.description,
    required this.gradientColors,
    required this.layout,
  });

  bool get isPremium => tier == TemplateTier.pro;

  TemplateLayoutFamily get layoutFamily {
    switch (layout) {
      case TemplateLayout.classic:
        return TemplateLayoutFamily.classic;
      case TemplateLayout.modern:
        return TemplateLayoutFamily.modern;
      case TemplateLayout.minimal:
        return TemplateLayoutFamily.minimal;
    }
  }
}

const List<ResumeTemplate> _templates = [
  ResumeTemplate(
    id: 'classic',
    name: 'Classic',
    tier: TemplateTier.free,
    atsScore: 98,
    emoji: '📋',
    description: 'Timeless & trusted',
    gradientColors: [0xFF475569, 0xFF334155],
    layout: TemplateLayout.classic,
  ),
  ResumeTemplate(
    id: 'modern',
    name: 'Modern',
    tier: TemplateTier.free,
    atsScore: 97,
    emoji: '⚡',
    description: 'Clean & contemporary',
    gradientColors: [0xFF6366F1, 0xFF4F46E5],
    layout: TemplateLayout.modern,
  ),
  ResumeTemplate(
    id: 'clean',
    name: 'Clean',
    tier: TemplateTier.free,
    atsScore: 99,
    emoji: '✨',
    description: 'Minimal & elegant',
    gradientColors: [0xFF059669, 0xFF047857],
    layout: TemplateLayout.minimal,
  ),
  ResumeTemplate(
    id: 'professional',
    name: 'Professional',
    tier: TemplateTier.free,
    atsScore: 96,
    emoji: '💼',
    description: 'Corporate ready',
    gradientColors: [0xFF2563EB, 0xFF1D4ED8],
    layout: TemplateLayout.classic,
  ),
  ResumeTemplate(
    id: 'minimal',
    name: 'Minimal',
    tier: TemplateTier.free,
    atsScore: 98,
    emoji: '🎯',
    description: 'Less is more',
    gradientColors: [0xFF374151, 0xFF1F2937],
    layout: TemplateLayout.minimal,
  ),
  ResumeTemplate(
    id: 'executive',
    name: 'Executive',
    tier: TemplateTier.free,
    atsScore: 97,
    emoji: '👔',
    description: 'Senior-level impact',
    gradientColors: [0xFF7C3AED, 0xFF6D28D9],
    layout: TemplateLayout.classic,
  ),
  ResumeTemplate(
    id: 'tech',
    name: 'Tech',
    tier: TemplateTier.free,
    atsScore: 96,
    emoji: '💻',
    description: 'Built for engineers',
    gradientColors: [0xFF0369A1, 0xFF075985],
    layout: TemplateLayout.modern,
  ),
  ResumeTemplate(
    id: 'creative_safe',
    name: 'Creative',
    tier: TemplateTier.free,
    atsScore: 95,
    emoji: '🎨',
    description: 'Stands out safely',
    gradientColors: [0xFFEA580C, 0xFFC2410C],
    layout: TemplateLayout.classic,
  ),
  ResumeTemplate(
    id: 'academic',
    name: 'Academic',
    tier: TemplateTier.free,
    atsScore: 98,
    emoji: '🎓',
    description: 'Research & academia',
    gradientColors: [0xFF166534, 0xFF14532D],
    layout: TemplateLayout.minimal,
  ),
  ResumeTemplate(
    id: 'simple',
    name: 'Simple',
    tier: TemplateTier.free,
    atsScore: 99,
    emoji: '📄',
    description: 'Always gets the job done',
    gradientColors: [0xFF374151, 0xFF111827],
    layout: TemplateLayout.minimal,
  ),
  ResumeTemplate(
    id: 'pro_elite',
    name: 'Elite',
    tier: TemplateTier.pro,
    atsScore: 99,
    emoji: '👑',
    description: 'Top 1% candidates',
    gradientColors: [0xFF7C3AED, 0xFF06B6D4],
    layout: TemplateLayout.modern,
  ),
  ResumeTemplate(
    id: 'pro_bold',
    name: 'Bold',
    tier: TemplateTier.pro,
    atsScore: 97,
    emoji: '🔥',
    description: 'Make an entrance',
    gradientColors: [0xFFDC2626, 0xFF9F1239],
    layout: TemplateLayout.modern,
  ),
  ResumeTemplate(
    id: 'pro_ivy',
    name: 'Ivy League',
    tier: TemplateTier.pro,
    atsScore: 98,
    emoji: '🏛️',
    description: 'Prestige & authority',
    gradientColors: [0xFF1E3A5F, 0xFF0F2942],
    layout: TemplateLayout.classic,
  ),
  ResumeTemplate(
    id: 'pro_startup',
    name: 'Startup',
    tier: TemplateTier.pro,
    atsScore: 96,
    emoji: '🚀',
    description: 'Built for builders',
    gradientColors: [0xFF7C3AED, 0xFF4F46E5],
    layout: TemplateLayout.modern,
  ),
  ResumeTemplate(
    id: 'pro_global',
    name: 'Global',
    tier: TemplateTier.pro,
    atsScore: 97,
    emoji: '🌍',
    description: 'International appeal',
    gradientColors: [0xFF0F766E, 0xFF134E4A],
    layout: TemplateLayout.classic,
  ),
];

Iterable<ResumeTemplate> get resumeTemplates => _templates;

Iterable<ResumeTemplate> resumeTemplatesForTier(TemplateTier tier) =>
    _templates.where((template) => template.tier == tier);

TemplateLayout templateLayoutForId(String? id) {
  for (final template in _templates) {
    if (template.id == id) return template.layout;
  }
  return TemplateLayout.classic;
}
