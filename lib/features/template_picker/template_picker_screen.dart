import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

const List<Map<String, dynamic>> kTemplates = [
  {'id': 'classic', 'name': 'Classic', 'premium': false, 'ats': 98, 'color': 0xFF475569},
  {'id': 'modern', 'name': 'Modern', 'premium': false, 'ats': 97, 'color': 0xFF6366F1},
  {'id': 'clean', 'name': 'Clean', 'premium': false, 'ats': 99, 'color': 0xFF059669},
  {'id': 'professional', 'name': 'Professional', 'premium': false, 'ats': 96, 'color': 0xFF2563EB},
  {'id': 'minimal', 'name': 'Minimal', 'premium': false, 'ats': 98, 'color': 0xFF111827},
  {'id': 'executive', 'name': 'Executive', 'premium': false, 'ats': 97, 'color': 0xFF7C3AED},
  {'id': 'tech', 'name': 'Tech', 'premium': false, 'ats': 96, 'color': 0xFF0369A1},
  {'id': 'creative_safe', 'name': 'Creative Safe', 'premium': false, 'ats': 95, 'color': 0xFFEA580C},
  {'id': 'academic', 'name': 'Academic', 'premium': false, 'ats': 98, 'color': 0xFF166534},
  {'id': 'simple', 'name': 'Simple', 'premium': false, 'ats': 99, 'color': 0xFF374151},
  {'id': 'pro_elite', 'name': 'Elite', 'premium': true, 'ats': 99, 'color': 0xFF6366F1},
  {'id': 'pro_bold', 'name': 'Bold', 'premium': true, 'ats': 97, 'color': 0xFFDC2626},
  {'id': 'pro_ivy', 'name': 'Ivy League', 'premium': true, 'ats': 98, 'color': 0xFF1E3A5F},
  {'id': 'pro_startup', 'name': 'Startup', 'premium': true, 'ats': 96, 'color': 0xFF7C3AED},
  {'id': 'pro_global', 'name': 'Global', 'premium': true, 'ats': 97, 'color': 0xFF0F766E},
];

class TemplatePickerScreen extends ConsumerStatefulWidget {
  const TemplatePickerScreen({super.key});
  @override
  ConsumerState<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends ConsumerState<TemplatePickerScreen> {
  String? _selectedId;

  void _select(Map<String, dynamic> template, bool isPro) {
    if (template['premium'] == true && !isPro) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Pro Template'),
        content: const Text('This template is available with Pro subscription.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            Navigator.pop(context); context.push('/pro');
          }, child: const Text('Upgrade to Pro')),
        ],
      ));
      return;
    }
    setState(() => _selectedId = template['id']);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider).value;
    final isPro = user?.plan == 'pro';
    
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Template'),
      actions: [
        if (_selectedId != null)
          TextButton(onPressed: () => context.push('/editor/new?template=$_selectedId'),
          child: const Text('Use This')),
      ]),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 0.72),
        itemCount: kTemplates.length,
        itemBuilder: (ctx, i) {
          final t = kTemplates[i];
          final isSelected = _selectedId == t['id'];
          return GestureDetector(
            onTap: () => _select(t, isPro),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
                  width: isSelected ? 3 : 1),
                boxShadow: isSelected ? [BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 12)] : null),
              child: Column(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(t['color']).withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
                    child: Center(child: Icon(Icons.description,
                      size: 48, color: Color(t['color']))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(children: [
                        if (t['premium'] == true)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber,
                          borderRadius: BorderRadius.circular(4)),
                          child: const Text('PRO', style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.bold))),
                        if (t['premium'] != true) ...[
                          const Icon(Icons.verified, size: 12, color: Colors.green),
                          const SizedBox(width: 2),
                          Text('ATS ${t['ats']}', style: const TextStyle(fontSize: 10, color: Colors.green)),
                        ],
                      ]),
                  ]),
                ),
              ]),
            ),
          );
        }),
    );
  }
}
