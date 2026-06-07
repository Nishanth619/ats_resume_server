import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/resume_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';

final resumeListProvider = StreamProvider<List<ResumeModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).resumesStream(user.uid);
});

final resumeStreamProvider = StreamProvider.family<ResumeModel, String>((
  ref,
  id,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw Exception('Not authenticated');

  if (id == 'new') {
    return Stream.value(
      ResumeModel(
        id: const Uuid().v4(),
        title: 'Untitled Resume',
        lastEdited: DateTime.now(),
        sections: {},
      ),
    );
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
          await ref
              .read(resumeStreamProvider(id).future)
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          // Silently ignore — user already has their data, this is best-effort
        }
      });

      return resume;
    } catch (_) {}
  }

  // 4. Await network fetch
  if (id == 'new') {
    throw Exception(
      'Cannot load an empty unsaved resume. Please go back and save.',
    );
  }

  return await ref
      .read(resumeStreamProvider(id).future)
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
          'Resume took too long to load from cloud. Please check your connection.',
        ),
      );
}

Future<ResumeModel> fetchResumeForExport(WidgetRef ref, String id) async {
  final local = ref.read(resumeNotifierProvider(id));
  if (local != null) return local;

  if (id == 'new') {
    throw Exception(
      'Cannot export an empty unsaved resume. Please save your resume first.',
    );
  }

  try {
    ref.invalidate(resumeStreamProvider(id));
    return await ref
        .read(resumeStreamProvider(id).future)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception(
            'Resume took too long to refresh from cloud. Please check your connection.',
          ),
        );
  } catch (_) {
    final cached = ref.read(resumeStreamProvider(id)).value;
    if (cached != null) return cached;
    rethrow;
  }
}

final resumeNotifierProvider =
    NotifierProvider.family<ResumeNotifier, ResumeModel?, String>(
      ResumeNotifier.new,
    );

class ResumeNotifier extends Notifier<ResumeModel?> {
  ResumeNotifier(this.resumeId);
  final String resumeId;

  @override
  ResumeModel? build() {
    // We get the initial state from the stream provider
    return ref.watch(resumeStreamProvider(resumeId)).value;
  }

  /// Pre-seed local state with a known ResumeModel.
  /// Used after creating a resume from an upload so that
  /// fetchResumeRobustly finds it instantly without a Firestore round-trip.
  void seed(ResumeModel resume) {
    state = resume;
  }

  Future<ResumeModel> _ensureResumeLoaded({
    String emptyResumeMessage =
        'Cannot tailor an empty unsaved resume. Please save your resume first.',
  }) async {
    if (state != null) return state!;

    final cached = ref.read(resumeStreamProvider(resumeId)).value;
    if (cached != null) {
      state = cached;
      return cached;
    }

    final list = ref.read(resumeListProvider).value;
    if (list != null) {
      for (final resume in list) {
        if (resume.id == resumeId) {
          state = resume;

          Future.microtask(() async {
            try {
              final fresh = await ref
                  .read(resumeStreamProvider(resumeId).future)
                  .timeout(const Duration(seconds: 15));
              state = fresh;
            } catch (_) {
              // The cached resume is enough to keep the action moving.
            }
          });

          return resume;
        }
      }
    }

    if (resumeId == 'new') {
      throw Exception(emptyResumeMessage);
    }

    try {
      final loaded = await ref
          .read(resumeStreamProvider(resumeId).future)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception(
              'Resume took too long to load from cloud. Please check your connection.',
            ),
          );
      state = loaded;
      return loaded;
    } catch (_) {
      throw Exception(
        'Unable to load this resume. Please open it once in the editor and try again.',
      );
    }
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
    );
  }

  Future<void> updateTargetJD(String jd) async {
    final resume = await _ensureResumeLoaded(
      emptyResumeMessage:
          'Cannot save a job description for an unsaved resume. Please save your resume first.',
    );
    state = ResumeModel(
      id: resume.id,
      title: resume.title,
      templateId: resume.templateId,
      colorTheme: resume.colorTheme,
      atsScore: resume.atsScore,
      sections: resume.sections,
      targetRole: resume.targetRole,
      targetJD: jd,
      lastEdited: DateTime.now(),
      downloadCount: resume.downloadCount,
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
    );
    await save();
  }

  Future<void> save() async {
    if (state == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) throw Exception('Not authenticated');

    await ref.read(firestoreServiceProvider).saveResume(user.uid, state!);
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapListFrom(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<String> _stringListFrom(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _normaliseKey(dynamic value) =>
      value == null ? '' : value.toString().trim().toLowerCase();

  Future<TailoredResumeResult> tailorToJD(
    String jd,
    AIService aiService, {
    bool dryRun = false,
  }) async {
    final original = await _ensureResumeLoaded();
    final result = await aiService.tailorResume(
      resumeSections: original.sections,
      jd: jd,
    );

    final user = ref.read(authStateProvider).value;
    // Only take a version snapshot when actually saving (not in dry-run preview)
    if (!dryRun && user != null && original.id.isNotEmpty) {
      try {
        final snapshot = original.toJson()..remove('versions');
        await ref
            .read(firestoreServiceProvider)
            .saveVersionSnapshot(user.uid, original.id, snapshot);
      } catch (_) {
        // Tailoring should still complete even if version backup fails.
      }
    }

    // Merge tailored sections back into the existing resume. Some backend
    // versions return flat fields, while others return a full sections object.
    final newSections = Map<String, dynamic>.from(original.sections);
    final tailoredSections = result.sections;

    // Update personal summary
    final personal = _mapFrom(newSections['personal']);
    final tailoredPersonal = _mapFrom(tailoredSections['personal']);
    final tailoredSummary = result.summary.trim().isNotEmpty
        ? result.summary
        : (tailoredPersonal['summary'] ?? '').toString();
    if (tailoredSummary.trim().isNotEmpty) {
      personal['summary'] = tailoredSummary;
    }
    newSections['personal'] = personal;

    // Update experience descriptions while preserving original metadata and order.
    if (result.experience.isNotEmpty) {
      final originalExperience = _mapListFrom(original.sections['experience']);
      final tailoredExperience = <Map<String, dynamic>>[];

      for (var i = 0; i < originalExperience.length; i++) {
        final originalItem = originalExperience[i];
        final tailoredItem = i < result.experience.length
            ? result.experience[i]
            : <String, dynamic>{};
        final description = (tailoredItem['description'] ?? '').toString();

        tailoredExperience.add({
          ...originalItem,
          if (description.trim().isNotEmpty) 'description': description,
        });
      }

      newSections['experience'] = tailoredExperience;
    }

    // Keep tailored/JD-relevant skills first, then preserve existing skills.
    final existingSkills = _stringListFrom(newSections['skills']);
    final tailoredSkillKeys = result.skills
        .map((skill) => skill.toLowerCase())
        .toSet();
    final remainingSkills = existingSkills
        .where((skill) => !tailoredSkillKeys.contains(skill.toLowerCase()))
        .toList();
    newSections['skills'] = [...result.skills, ...remainingSkills];

    // Update project descriptions while preserving project metadata and order.
    if (result.projects.isNotEmpty) {
      final originalProjects = _mapListFrom(original.sections['projects']);
      final tailoredProjects = <Map<String, dynamic>>[];

      for (var i = 0; i < originalProjects.length; i++) {
        final originalItem = originalProjects[i];
        final tailoredItem = i < result.projects.length
            ? result.projects[i]
            : <String, dynamic>{};
        final description = (tailoredItem['description'] ?? '').toString();

        tailoredProjects.add({
          ...originalItem,
          if (description.trim().isNotEmpty) 'description': description,
        });
      }

      newSections['projects'] = tailoredProjects;
    }

    // Add optional education highlights without changing degree metadata.
    if (result.education.isNotEmpty) {
      final originalEducation = _mapListFrom(original.sections['education']);
      final tailoredEducation = <Map<String, dynamic>>[];

      for (var i = 0; i < originalEducation.length; i++) {
        final originalItem = originalEducation[i];
        final tailoredItem = i < result.education.length
            ? result.education[i]
            : <String, dynamic>{};
        final highlights = (tailoredItem['highlights'] ?? '').toString().trim();

        tailoredEducation.add({
          ...originalItem,
          if (highlights.isNotEmpty) 'highlights': highlights,
        });
      }

      newSections['education'] = tailoredEducation;
    }

    // Reorder certifications by JD relevance while preserving original content.
    if (result.certifications.isNotEmpty) {
      final originalCertifications = _mapListFrom(
        original.sections['certifications'],
      );
      final certsByName = <String, Map<String, dynamic>>{};
      final unnamedCerts = <Map<String, dynamic>>[];

      for (final cert in originalCertifications) {
        final key = _normaliseKey(cert['name']);
        if (key.isEmpty) {
          unnamedCerts.add(cert);
        } else {
          certsByName[key] = cert;
        }
      }

      final reorderedCertifications = <Map<String, dynamic>>[];
      for (final cert in result.certifications) {
        final key = _normaliseKey(cert['name']);
        final originalCert = certsByName.remove(key);
        if (originalCert != null) reorderedCertifications.add(originalCert);
      }

      reorderedCertifications
        ..addAll(certsByName.values)
        ..addAll(unnamedCerts);
      newSections['certifications'] = reorderedCertifications;
    }

    state = ResumeModel(
      id: original.id,
      title: original.title,
      templateId: original.templateId,
      colorTheme: original.colorTheme,
      atsScore: original.atsScore,
      sections: newSections,
      targetRole: result.targetRole.isNotEmpty
          ? result.targetRole
          : original.targetRole,
      targetJD: jd,
      lastEdited: DateTime.now(),
      downloadCount: original.downloadCount,
    );

    if (!dryRun) await save();
    return result;
  }

  /// Pass 2 of the two-pass tailoring flow.
  ///
  /// Takes the [missingKeywords] list from the matchJD result and injects
  /// any that are not already in the resume's skills section.
  /// Returns the count of newly added keywords.
  Future<int> injectKeywords(
    List<String> missingKeywords, {
    bool dryRun = false,
  }) async {
    final current = await _ensureResumeLoaded();
    final existingSkills = (current.sections['skills'] as List? ?? [])
        .map((s) => s.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final existingLower = existingSkills.map((s) => s.toLowerCase()).toSet();

    // Only add keywords that are not already present (case-insensitive dedup)
    final newKeywords = missingKeywords
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty && !existingLower.contains(k.toLowerCase()))
        .toList();

    if (newKeywords.isEmpty) return 0;

    // JD keywords go first so ATS sees them early in the list
    final mergedSkills = [...newKeywords, ...existingSkills];

    final newSections = Map<String, dynamic>.from(current.sections)
      ..['skills'] = mergedSkills;

    state = ResumeModel(
      id: current.id,
      title: current.title,
      templateId: current.templateId,
      colorTheme: current.colorTheme,
      atsScore: current.atsScore,
      sections: newSections,
      targetRole: current.targetRole,
      targetJD: current.targetJD,
      lastEdited: DateTime.now(),
      downloadCount: current.downloadCount,
    );

    if (!dryRun) await save();
    return newKeywords.length;
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

final resumeActionsProvider = Provider<ResumeActions>(
  (ref) => ResumeActions(ref),
);
