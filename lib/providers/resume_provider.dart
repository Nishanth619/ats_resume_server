import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/resume_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';

final resumeListProvider = StreamProvider<List<ResumeModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).resumesStream(user.uid);
});

final resumeStreamProvider = StreamProvider.family<ResumeModel, String>((ref, id) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw Exception('Not authenticated');
  
  if (id == 'new') {
    return Stream.value(ResumeModel(
      id: const Uuid().v4(),
      title: 'Untitled Resume',
      lastEdited: DateTime.now(),
      sections: {},
    ));
  }
  
  return ref.watch(firestoreServiceProvider).resumeStream(user.uid, id);
});

Future<ResumeModel> fetchResumeRobustly(WidgetRef ref, String id) async {
  // 1. Check local editor memory
  ResumeModel? resume = ref.read(resumeNotifierProvider(id));
  if (resume != null) return resume;

  // 2. Check stream cache
  resume = ref.read(resumeStreamProvider(id)).value;
  if (resume != null) return resume;

  // 3. Check dashboard list cache (fixes offline timeout for existing resumes)
  final list = ref.read(resumeListProvider).value;
  if (list != null) {
    try {
      resume = list.firstWhere((r) => r.id == id);
      
      // 🔄 Silently refresh in background so the single-resume stream stays fresh
      Future.microtask(() async {
        try {
          // Reading the future forces the stream to activate and fetch the latest from Firebase
          await ref.read(resumeStreamProvider(id).future).timeout(const Duration(seconds: 15));
        } catch (_) {
          // Silently ignore — user already has their data, this is best-effort
        }
      });

      return resume;
    } catch (_) {}
  }

  // 4. Await network fetch
  if (id == 'new') {
    throw Exception('Cannot load an empty unsaved resume. Please go back and save.');
  }
  
  return await ref.read(resumeStreamProvider(id).future).timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw Exception('Resume took too long to load from cloud. Please check your connection.'),
  );
}

final resumeNotifierProvider =
    NotifierProvider.family<ResumeNotifier, ResumeModel?, String>(
        ResumeNotifier.new);

class ResumeNotifier extends Notifier<ResumeModel?> {
  ResumeNotifier(this.resumeId);
  final String resumeId;

  @override
  ResumeModel? build() {
    // We get the initial state from the stream provider
    return ref.watch(resumeStreamProvider(resumeId)).value;
  }

  void updateSection(String section, dynamic data) {
    if (state == null) return;
    
    final newSections = Map<String, dynamic>.from(state!.sections);
    newSections[section] = data;
    
    state = ResumeModel(
      id: state!.id,
      title: state!.title,
      templateId: state!.templateId,
      colorTheme: state!.colorTheme,
      atsScore: state!.atsScore,
      sections: newSections,
      targetRole: state!.targetRole,
      targetJD: state!.targetJD,
      lastEdited: DateTime.now(),
      downloadCount: state!.downloadCount,
      versions: state!.versions,
    );
  }

  void setTemplate(String templateId) {
    if (state == null) return;
    state = ResumeModel(
      id: state!.id,
      title: state!.title,
      templateId: templateId,
      colorTheme: state!.colorTheme,
      atsScore: state!.atsScore,
      sections: state!.sections,
      targetRole: state!.targetRole,
      targetJD: state!.targetJD,
      lastEdited: DateTime.now(),
      downloadCount: state!.downloadCount,
      versions: state!.versions,
    );
  }
  
  Future<void> updateTargetJD(String jd) async {
    if (state == null) return;
    state = ResumeModel(
      id: state!.id,
      title: state!.title,
      templateId: state!.templateId,
      colorTheme: state!.colorTheme,
      atsScore: state!.atsScore,
      sections: state!.sections,
      targetRole: state!.targetRole,
      targetJD: jd,
      lastEdited: DateTime.now(),
      downloadCount: state!.downloadCount,
      versions: state!.versions,
    );
    await save();
  }
  
  Future<void> updateATSScore(int score) async {
    if (state == null) return;
    state = ResumeModel(
      id: state!.id,
      title: state!.title,
      templateId: state!.templateId,
      colorTheme: state!.colorTheme,
      atsScore: score,
      sections: state!.sections,
      targetRole: state!.targetRole,
      targetJD: state!.targetJD,
      lastEdited: DateTime.now(),
      downloadCount: state!.downloadCount,
      versions: state!.versions,
    );
    await save();
  }

  Future<void> incrementDownload() async {
    if (state == null) return;
    state = ResumeModel(
      id: state!.id,
      title: state!.title,
      templateId: state!.templateId,
      colorTheme: state!.colorTheme,
      atsScore: state!.atsScore,
      sections: state!.sections,
      targetRole: state!.targetRole,
      targetJD: state!.targetJD,
      lastEdited: DateTime.now(),
      downloadCount: state!.downloadCount + 1,
      versions: state!.versions,
    );
    await save();
  }

  Future<void> save() async {
    if (state == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) throw Exception('Not authenticated');
    
    await ref.read(firestoreServiceProvider).saveResume(user.uid, state!);
  }

  Future<void> tailorToJD(String jd, dynamic aiService) async {
    if (state == null) return;
    final result = await aiService.tailorResume(
      resumeSections: state!.sections,
      jd: jd,
    );
    // Merge tailored sections back into existing resume
    final newSections = Map<String, dynamic>.from(state!.sections);
    
    // Update personal summary
    final personal = Map<String, dynamic>.from(newSections['personal'] ?? {});
    personal['summary'] = result.summary;
    newSections['personal'] = personal;

    // Update experience descriptions
    newSections['experience'] = result.experience;

    // Merge skills (union of old + new)
    final existingSkills = List<String>.from(newSections['skills'] ?? []);
    final mergedSkills = {...existingSkills, ...result.skills}.toList();
    newSections['skills'] = mergedSkills;

    state = ResumeModel(
      id: state!.id,
      title: state!.title,
      templateId: state!.templateId,
      colorTheme: state!.colorTheme,
      atsScore: state!.atsScore,
      sections: newSections,
      targetRole: result.targetRole.isNotEmpty ? result.targetRole : state!.targetRole,
      targetJD: jd,
      lastEdited: DateTime.now(),
      downloadCount: state!.downloadCount,
      versions: state!.versions,
    );

    await save();
  }
}

// Actions provider for dashboard operations (delete, duplicate, etc.)
class ResumeActions {
  final Ref _ref;
  ResumeActions(this._ref);

  Future<void> deleteResume(String resumeId) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;
    await _ref.read(firestoreServiceProvider).deleteResume(user.uid, resumeId);
  }

  Future<String> createNewResume(String templateId) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) throw Exception('Not authenticated');
    final resume = ResumeModel(
      id: '',
      title: 'Untitled Resume',
      templateId: templateId,
      lastEdited: DateTime.now(),
      sections: {
        'personal': <String, dynamic>{},
        'experience': <Map<String, dynamic>>[],
        'education': <Map<String, dynamic>>[],
        'skills': <String>[],
        'projects': <Map<String, dynamic>>[],
        'certifications': <Map<String, dynamic>>[],
      },
    );
    return _ref.read(firestoreServiceProvider).createResume(user.uid, resume);
  }
}

final resumeActionsProvider = Provider<ResumeActions>((ref) => ResumeActions(ref));

