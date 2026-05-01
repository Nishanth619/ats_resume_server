import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_provider.dart';
import '../../models/application_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shared_widgets.dart';

const Map<ApplicationStatus, _ColConfig> kColConfig = {
  ApplicationStatus.applied: _ColConfig(
      'Applied', AppColors.primaryLight, Color(0xFF1E1B33), '📤'),
  ApplicationStatus.interview: _ColConfig(
      'Interview', AppColors.accentGold, Color(0xFF1E1A10), '🎤'),
  ApplicationStatus.offer: _ColConfig(
      'Offer', AppColors.scoreGreen, Color(0xFF0E1F18), '🎉'),
  ApplicationStatus.rejected: _ColConfig(
      'Rejected', AppColors.scoreRed, Color(0xFF1F0E0E), '❌'),
};

class _ColConfig {
  final String label;
  final Color accent, bg;
  final String emoji;
  const _ColConfig(this.label, this.accent, this.bg, this.emoji);
}

class JobTrackerScreen extends ConsumerWidget {
  const JobTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final appsAsync = ref.watch(applicationsStreamProvider(uid));

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
              shaderCallback: (b) => AppColors.accentGradient.createShader(b),
              child: const Text('Job Tracker',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            actions: [
              appsAsync.whenOrNull(
                    data: (list) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: GradientBadge(
                          text: '${list.length} jobs',
                          gradient: AppColors.accentGradient),
                    ),
                  ) ??
                  const SizedBox(),
              IconButton(
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
                onPressed: () => _showAddDialog(context, ref, uid),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: appsAsync.when(
              loading: () => const SizedBox(
                height: 400,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight)),
              ),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style:
                          const TextStyle(color: AppColors.textSecondary))),
              data: (rawList) {
                final apps = rawList
                    .map((m) =>
                        ApplicationModel.fromMap(m['id'] as String, m))
                    .toList();
                return Column(
                  children: [
                    _StatsBar(apps: apps),
                    // LayoutBuilder gives us a bounded height — avoids grey
                    // screen when keyboard opens/closes or MediaQuery shifts
                    LayoutBuilder(
                      builder: (ctx2, constraints) {
                        // Remaining screen height after stats bar (~90) + appbar (~56)
                        final columnH =
                            MediaQuery.of(ctx2).size.height - 56 - 90 - 48;
                        return SizedBox(
                          height: columnH.clamp(300.0, 800.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ApplicationStatus.values
                                  .map((status) => _KanbanColumn(
                                        uid: uid,
                                        status: status,
                                        apps: apps
                                            .where((a) => a.status == status)
                                            .toList(),
                                        ref: ref,
                                        columnHeight:
                                            columnH.clamp(300.0, 800.0) - 60,
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, WidgetRef ref, String uid) {
    final compCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    ApplicationStatus status = ApplicationStatus.applied;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setState2) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx2).viewInsets.bottom + 24),
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
              const SizedBox(height: 20),
              const Text('Add Application',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              _DarkField(controller: compCtrl, label: 'Company *',
                  icon: Icons.business_outlined),
              const SizedBox(height: 12),
              _DarkField(controller: roleCtrl, label: 'Role / Job Title *',
                  icon: Icons.work_outline_rounded),
              const SizedBox(height: 12),
              _DarkField(controller: urlCtrl, label: 'Job URL (optional)',
                  icon: Icons.link_rounded),
              const SizedBox(height: 12),
              // Status picker
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ApplicationStatus.values.map((s) {
                    final cfg = kColConfig[s]!;
                    final selected = status == s;
                    return GestureDetector(
                      onTap: () => setState2(() => status = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? cfg.accent.withOpacity(0.15)
                              : AppColors.cardDark2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? cfg.accent
                                  : AppColors.borderDark,
                              width: selected ? 1.5 : 1),
                        ),
                        child: Text('${cfg.emoji} ${cfg.label}',
                            style: TextStyle(
                                color: selected
                                    ? cfg.accent
                                    : AppColors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Add to Tracker',
                onPressed: () {
                  if (compCtrl.text.trim().isEmpty ||
                      roleCtrl.text.trim().isEmpty) return;
                  ref.read(firestoreServiceProvider).addApplication(uid, {
                    'company': compCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'status': status.value,
                    'notes': '',
                    if (urlCtrl.text.trim().isNotEmpty)
                      'jobUrl': urlCtrl.text.trim(),
                  });
                  Navigator.pop(ctx2);
                },
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _DarkField(
      {required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final List<ApplicationModel> apps;
  const _StatsBar({required this.apps});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: ApplicationStatus.values.map((s) {
          final count = apps.where((a) => a.status == s).length;
          final cfg = kColConfig[s]!;
          return Expanded(
            child: Column(
              children: [
                Text('$count',
                    style: TextStyle(
                        color: cfg.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(cfg.label,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  final String uid;
  final ApplicationStatus status;
  final List<ApplicationModel> apps;
  final WidgetRef ref;
  final double columnHeight;

  const _KanbanColumn({
    required this.uid,
    required this.status,
    required this.apps,
    required this.ref,
    required this.columnHeight,
  });

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  bool _isDragOver = false;

  void _onAccept(ApplicationModel app) {
    if (app.status == widget.status) return;
    widget.ref
        .read(firestoreServiceProvider)
        .updateApplicationStatus(widget.uid, app.id, widget.status.value);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = kColConfig[widget.status]!;

    return DragTarget<ApplicationModel>(
      onWillAcceptWithDetails: (details) {
        final willAccept = details.data.status != widget.status;
        setState(() => _isDragOver = willAccept);
        return willAccept;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        _onAccept(details.data);
      },
      builder: (ctx, _, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 220,
        // Fixed height — no Flexible or Expanded inside DragTarget to avoid
        // unbounded constraints that cause the grey screen bug
        height: widget.columnHeight,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _isDragOver
              ? cfg.accent.withOpacity(0.08)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _isDragOver ? cfg.accent : AppColors.borderDark,
              width: _isDragOver ? 2 : 1),
          boxShadow: _isDragOver
              ? [
                  BoxShadow(
                      color: cfg.accent.withOpacity(0.2),
                      blurRadius: 16)
                ]
              : null,
        ),
        child: Column(
          children: [
            // Column header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: cfg.accent.withOpacity(0.12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                border: Border(
                    bottom: BorderSide(
                        color: cfg.accent.withOpacity(0.3), width: 1)),
              ),
              child: Row(
                children: [
                  Text(cfg.emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cfg.label,
                        style: TextStyle(
                            color: cfg.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cfg.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${widget.apps.length}',
                        style: TextStyle(
                            color: cfg.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // Cards list — Expanded is safe here because parent AnimatedContainer
            // now has a fixed height (no more unbounded constraint crash)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: widget.apps
                      .map((app) => _DraggableCard(
                          app: app, uid: widget.uid, ref: widget.ref))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableCard extends StatefulWidget {
  final ApplicationModel app;
  final String uid;
  final WidgetRef ref;
  const _DraggableCard(
      {required this.app, required this.uid, required this.ref});

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<ApplicationModel>(
      data: widget.app,
      delay: const Duration(milliseconds: 150),
      onDragStarted: () => setState(() => _isDragging = true),
      onDragEnd: (_) => setState(() => _isDragging = false),
      onDraggableCanceled: (_, __) => setState(() => _isDragging = false),
      childWhenDragging: Opacity(
          opacity: 0.3,
          child: _CardContent(
              app: widget.app, uid: widget.uid, ref: widget.ref)),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
            width: 200,
            child: _CardContent(
                app: widget.app,
                uid: widget.uid,
                ref: widget.ref,
                isFloating: true)),
      ),
      child: AnimatedScale(
        scale: _isDragging ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: _CardContent(
            app: widget.app, uid: widget.uid, ref: widget.ref),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final ApplicationModel app;
  final String uid;
  final WidgetRef ref;
  final bool isFloating;
  const _CardContent(
      {required this.app,
      required this.uid,
      required this.ref,
      this.isFloating = false});

  @override
  Widget build(BuildContext context) {
    final cfg = kColConfig[app.status]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isFloating ? cfg.accent : AppColors.borderDark, width: 1),
        boxShadow: isFloating
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 28,
                height: 3,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.company,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(app.role,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                if (!isFloating)
                  PopupMenuButton<String>(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    iconColor: AppColors.textMuted,
                    color: AppColors.cardDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                color: AppColors.error, size: 16),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(
                                    color: AppColors.error, fontSize: 13)),
                          ])),
                    ],
                    onSelected: (val) {
                      if (val == 'delete') {
                        ref
                            .read(firestoreServiceProvider)
                            .deleteApplication(uid, app.id);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 10, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                    '${app.appliedAt.day}/${app.appliedAt.month}/${app.appliedAt.year}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
                if (app.notes.isNotEmpty) ...[
                  const Spacer(),
                  const Icon(Icons.note_outlined,
                      size: 10, color: AppColors.textMuted),
                ],
              ],
            ),
            if (app.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(app.notes,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
