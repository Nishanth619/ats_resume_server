import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/resume_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/resume_model.dart';
import '../../services/auth_service.dart';
import '../../services/admob_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumes = ref.watch(resumeListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Resumes'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF6366F1)),
              child: Text('ATS Resume Builder', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('Job Tracker'),
              onTap: () {
                Navigator.pop(context);
                context.push('/job-tracker');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                ref.read(authServiceProvider).signOut();
              },
            ),
          ],
        ),
      ),
      body: resumes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _ResumeCard(resume: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates'),
        icon: const Icon(Icons.add),
        label: const Text('New Resume'),
      ),
      bottomNavigationBar: ref.watch(bannerAdProvider) ?? const SizedBox(height: 50),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.description_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No resumes yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create your first ATS-optimised resume',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: () => context.push('/templates'),
              child: const Text('Create Resume')),
        ]),
      );
}

class _ResumeCard extends ConsumerWidget {
  final ResumeModel resume;
  const _ResumeCard({required this.resume});

  Color _scoreColor(int score) => score >= 80
      ? Colors.green
      : score >= 60
          ? Colors.orange
          : Colors.red;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(resume.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Text('Last edited: \${_formatDate(resume.lastEdited)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text('Downloads: ${resume.downloadCount}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _scoreColor(resume.atsScore).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _scoreColor(resume.atsScore))),
            child: Text('${resume.atsScore}',
                style: TextStyle(
                    color: _scoreColor(resume.atsScore), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          const Text('ATS', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
        onTap: () => context.push('/editor/${resume.id}'),
        onLongPress: () => _showOptions(context, ref),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showOptions(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
        context: ctx,
        builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('Preview'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ctx.push('/preview/${resume.id}');
                    }),
                ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(resumeActionsProvider).deleteResume(resume.id);
                    }),
              ],
            ),
            ));
  }
}
