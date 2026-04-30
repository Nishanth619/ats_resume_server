import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_provider.dart';
import '../../models/application_model.dart';

// Status config
// ignore: library_private_types_in_public_api
const Map<ApplicationStatus, _ColConfig> kColConfig = {
  ApplicationStatus.applied: _ColConfig('Applied', Color(0xFF6366F1), Color(0xFFEEF2FF)),
  ApplicationStatus.interview: _ColConfig('Interview', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
  ApplicationStatus.offer: _ColConfig('Offer', Color(0xFF10B981), Color(0xFFECFDF5)),
  ApplicationStatus.rejected: _ColConfig('Rejected', Color(0xFFEF4444), Color(0xFFFEF2F2)),
};

class _ColConfig {
  final String label;
  final Color accent, bg;
  const _ColConfig(this.label, this.accent, this.bg);
}

// Screen
class JobTrackerScreen extends ConsumerWidget {
  const JobTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final appsAsync = ref.watch(applicationsStreamProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Tracker'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Application',
              onPressed: () => _showAddDialog(context, ref, uid)),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rawList) {
          // Convert raw maps to ApplicationModel
          final apps = rawList
              .map((m) => ApplicationModel.fromMap(m['id'] as String, m))
              .toList();

          return Column(children: [
            // Stats bar
            _StatsBar(apps: apps),
            // Kanban board
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: ApplicationStatus.values
                      .map((status) => _KanbanColumn(
                            uid: uid,
                            status: status,
                            apps: apps.where((a) => a.status == status).toList(),
                            allApps: apps,
                            ref: ref,
                          ))
                      .toList(),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, WidgetRef ref, String uid) {
    final compCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    ApplicationStatus status = ApplicationStatus.applied;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
          builder: (ctx2, setState2) => AlertDialog(
                title: const Text('Add Application'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: compCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Company *', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: roleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Role / Job Title *',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Job URL (optional)',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ApplicationStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(
                          labelText: 'Stage', border: OutlineInputBorder()),
                      items: ApplicationStatus.values
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(kColConfig[s]!.label)))
                          .toList(),
                      onChanged: (v) => setState2(() => status = v!)),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx2),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (compCtrl.text.trim().isEmpty ||
                            roleCtrl.text.trim().isEmpty) { return; }
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
                      child: const Text('Add')),
                ],
              )),
    );
  }
}

// Stats bar
class _StatsBar extends StatelessWidget {
  final List<ApplicationModel> apps;
  const _StatsBar({required this.apps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
          children: ApplicationStatus.values.map((s) {
        final count = apps.where((a) => a.status == s).length;
        final cfg = kColConfig[s]!;
        return Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                  color: cfg.accent, shape: BoxShape.circle)),
          Text('${cfg.label}: $count',
              style: TextStyle(
                  fontSize: 12,
                  color: cfg.accent,
                  fontWeight: FontWeight.w600)),
        ]));
      }).toList()),
    );
  }
}

// Kanban Column with DragTarget
class _KanbanColumn extends StatefulWidget {
  final String uid;
  final ApplicationStatus status;
  final List<ApplicationModel> apps;
  final List<ApplicationModel> allApps;
  final WidgetRef ref;

  const _KanbanColumn({
    required this.uid,
    required this.status,
    required this.apps,
    required this.allApps,
    required this.ref,
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
      builder: (ctx, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 210,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _isDragOver
                ? cfg.accent.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _isDragOver ? cfg.accent : Colors.grey.shade200,
                width: _isDragOver ? 2 : 1),
            boxShadow: _isDragOver
                ? [BoxShadow(color: cfg.accent.withValues(alpha: 0.2), blurRadius: 12)]
                : null,
          ),
          child: Column(children: [
            // Column header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: cfg.accent,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11))),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cfg.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${widget.apps.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11))),
                  ]),
            ),
            // Drop hint when dragging over
            if (_isDragOver)
              Container(
                  margin: const EdgeInsets.all(8),
                  height: 4,
                  decoration: BoxDecoration(
                      color: cfg.accent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2))),
            // Cards
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: widget.apps
                      .map((app) => _DraggableCard(
                          app: app, uid: widget.uid, ref: widget.ref))
                      .toList(),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// Draggable Card
class _DraggableCard extends StatefulWidget {
  final ApplicationModel app;
  final String uid;
  final WidgetRef ref;

  const _DraggableCard({
    required this.app,
    required this.uid,
    required this.ref,
  });

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
      onDraggableCanceled: (velocity, offset) => setState(() => _isDragging = false),
      // Ghost left in column while dragging
      childWhenDragging: Opacity(
          opacity: 0.35,
          child: _CardContent(
              app: widget.app, uid: widget.uid, ref: widget.ref, isDragging: true)),
      // The dragged widget (floating above)
      feedback: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            width: 195,
            child: _CardContent(
                app: widget.app,
                uid: widget.uid,
                ref: widget.ref,
                isDragging: true,
                isFloating: true)),
      ),
      child: AnimatedScale(
          scale: _isDragging ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: _CardContent(
              app: widget.app, uid: widget.uid, ref: widget.ref, isDragging: _isDragging)),
    );
  }
}

// Card Content
class _CardContent extends StatefulWidget {
  final ApplicationModel app;
  final String uid;
  final WidgetRef ref;
  final bool isDragging;
  final bool isFloating;

  const _CardContent({
    required this.app,
    required this.uid,
    required this.ref,
    this.isDragging = false,
    this.isFloating = false,
  });

  @override
  State<_CardContent> createState() => _CardContentState();
}

class _CardContentState extends State<_CardContent> {
  @override
  Widget build(BuildContext context) {
    final cfg = kColConfig[widget.app.status]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: widget.isDragging && !widget.isFloating
                ? cfg.accent.withValues(alpha: 0.4)
                : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: widget.isDragging
                  ? Colors.black26
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: widget.isDragging ? 8 : 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drag handle hint
          Center(
              child: Container(
                  width: 24,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
          Text(widget.app.company,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(widget.app.role,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
                '${widget.app.appliedAt.day}/${widget.app.appliedAt.month}/${widget.app.appliedAt.year}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            if (!widget.isFloating)
              PopupMenuButton<String>(
                iconSize: 16,
                padding: EdgeInsets.zero,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'notes', child: Text('Edit Notes')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (val) {
                  if (val == 'delete') {
                    widget.ref
                        .read(firestoreServiceProvider)
                        .deleteApplication(widget.uid, widget.app.id);
                  }
                  if (val == 'notes') _editNotes(context);
                },
              ),
          ]),
          if (widget.app.notes.isNotEmpty) ...[
            const Divider(height: 12),
            Text(widget.app.notes,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  void _editNotes(BuildContext ctx) {
    final ctrl = TextEditingController(text: widget.app.notes);
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              title: const Text('Notes'),
              content: TextField(
                  controller: ctrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Add notes about this application...')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      widget.ref
                          .read(firestoreServiceProvider)
                          .updateApplicationStatus(widget.uid, widget.app.id, widget.app.status.value);
                      // Also save notes - add updateApplicationNotes to FirestoreService
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save')),
              ],
            ));
  }
}
