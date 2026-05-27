import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/config/app_config.dart';

// ─── Cover Letter Result ───────────────────────────────────────────────────────
class CoverLetterResult {
  final String letter;
  final String engine; // 'gemini' | 'groq' | 'mock'
  final int wordCount;

  const CoverLetterResult({
    required this.letter,
    required this.engine,
    required this.wordCount,
  });

  factory CoverLetterResult.fromJson(Map<String, dynamic> json) {
    final letter = (json['letter'] as String?) ?? '';
    if (letter.trim().isEmpty) {
      throw const FormatException('Empty letter in response');
    }
    return CoverLetterResult(
      letter: letter,
      engine: (json['engine'] as String?) ?? 'unknown',
      wordCount:
          (json['wordCount'] as int?) ??
          letter.trim().split(RegExp(r'\s+')).length,
    );
  }
}

// ─── Sealed AI Exception hierarchy ────────────────────────────────────────────
sealed class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);
  @override
  String toString() => message;
}

class CoverLetterNetworkException extends AiServiceException {
  const CoverLetterNetworkException(super.m);
}

class CoverLetterServerException extends AiServiceException {
  const CoverLetterServerException(super.m);
}

class CoverLetterValidationException extends AiServiceException {
  const CoverLetterValidationException(super.m);
}

class CoverLetterTimeoutException extends AiServiceException {
  const CoverLetterTimeoutException(super.m);
}

final aiServiceProvider = Provider<AIService>(
  (ref) => AIService(backendUrl: AppConfig.backendUrl),
);

class AIService {
  final String _baseUrl;

  AIService({required String backendUrl}) : _baseUrl = backendUrl;

  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<String> improveBullet(String rawDuty, String role) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/improve-bullet'),
      headers: await _getHeaders(),
      body: jsonEncode({'rawDuty': rawDuty, 'role': role}),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['bullet'];
  }

  Future<String> generateSummary({
    required String name,
    required String targetRole,
    required List<String> experiences,
    required List<String> skills,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/summary'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'targetRole': targetRole.trim().isEmpty
            ? 'General professional role'
            : targetRole,
        'experiences': experiences,
        'skills': skills,
      }),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['summary'];
  }

  Future<ATSResult> checkATS(
    String resumeText, {
    String? targetJD,
    Map<String, dynamic>? sections, // Fix 6: send structured sections too
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/ats-check'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'resumeText': resumeText,
        'targetJD': targetJD,
        ...?((sections != null) ? {'sections': sections} : null),
      }),
    );
    if (response.statusCode == 429) {
      throw Exception(jsonDecode(response.body)['error']);
    }
    if (response.statusCode != 200) {
      // Try to extract a readable error from the server body
      String msg =
          'Analysis failed (server error ${response.statusCode}). Please retry.';
      try {
        msg = jsonDecode(response.body)['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
    return ATSResult.fromJson(jsonDecode(response.body));
  }

  Future<KeywordMatchResult> matchJD(String resumeText, String jd) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/match-jd'),
      headers: await _getHeaders(),
      body: jsonEncode({'resumeText': resumeText, 'jd': jd}),
    );
    if (response.statusCode == 429) {
      throw Exception(jsonDecode(response.body)['error']);
    }
    if (response.statusCode != 200) {
      String msg = 'Job match analysis failed (${response.statusCode}). Please retry.';
      try { msg = jsonDecode(response.body)['error'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
    return KeywordMatchResult.fromJson(jsonDecode(response.body));
  }

  // LinkedIn import is handled by linkedin_service.dart — see that file for the real implementation.

  Future<CoverLetterResult> generateCoverLetter({
    required String resumeText,
    required String company,
    required String name,
    String? jd,
  }) async {
    // Client-side validation before burning an API call
    if (resumeText.trim().length < 50) {
      throw const CoverLetterValidationException(
        'Resume is too short to generate a cover letter. Please add more content first.',
      );
    }
    if (company.trim().isEmpty) {
      throw const CoverLetterValidationException('Company name is required.');
    }
    if (name.trim().isEmpty) {
      throw const CoverLetterValidationException('Your name is required.');
    }

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/cover-letter'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'resumeText': resumeText.trim(),
              'company': company.trim(),
              'name': name.trim(),
              if (jd != null && jd.trim().isNotEmpty) 'jd': jd.trim(),
            }),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw const CoverLetterTimeoutException(
              'The AI is taking too long. Please try again.',
            ),
          );
    } on CoverLetterTimeoutException {
      rethrow;
    } on SocketException {
      throw const CoverLetterNetworkException(
        'No internet connection. Check your network and try again.',
      );
    } catch (e) {
      if (e is AiServiceException) rethrow;
      throw CoverLetterNetworkException('Network error: ${e.toString()}');
    }

    // Safe JSON decode
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const CoverLetterServerException(
        'Received an invalid response from the server.',
      );
    }

    // Per-status error handling
    if (response.statusCode == 400) {
      throw CoverLetterValidationException(
        (body['error'] as String?) ?? 'Invalid request',
      );
    }
    if (response.statusCode == 503 || response.statusCode == 502) {
      throw CoverLetterServerException(
        (body['error'] as String?) ??
            'AI service unavailable. Please try again shortly.',
      );
    }
    if (response.statusCode != 200) {
      throw CoverLetterServerException(
        'Server error (${response.statusCode}). Please try again.',
      );
    }

    try {
      return CoverLetterResult.fromJson(body);
    } on FormatException catch (e) {
      throw CoverLetterServerException(
        'Could not parse cover letter: ${e.message}',
      );
    }
  }

  Future<TailoredResumeResult> tailorResume({
    required Map<String, dynamic> resumeSections,
    required String jd,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/tailor-resume'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'resume': {'sections': resumeSections},
        'jd': jd,
      }),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return TailoredResumeResult.fromJson(jsonDecode(response.body));
  }

  /// Parse an uploaded resume PDF or raw text into structured sections.
  Future<ParsedResumeResult> parseResume({
    String? pdfBase64,
    String? resumeText,
    String? fileName,
  }) async {
    assert(pdfBase64 != null || resumeText != null,
        'Either pdfBase64 or resumeText is required');

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/parse-resume'),
            headers: await _getHeaders(),
            body: jsonEncode({
              // ignore: use_null_aware_elements
              if (pdfBase64 != null) 'pdfBase64': pdfBase64,
              // ignore: use_null_aware_elements
              if (resumeText != null) 'resumeText': resumeText,
              // ignore: use_null_aware_elements
              if (fileName != null) 'fileName': fileName,
            }),
          )
          .timeout(
            const Duration(seconds: 70),
            onTimeout: () => throw Exception(
              'Resume parsing timed out. Please try again.',
            ),
          );
    } on SocketException {
      throw Exception('No internet connection. Check your network and try again.');
    }

    if (response.statusCode == 429) {
      throw Exception(jsonDecode(response.body)['error'] ??
          'Daily limit reached. Upgrade to Pro for unlimited resume uploads.');
    }
    if (response.statusCode != 200) {
      String msg = 'Failed to parse resume (${response.statusCode}). Please retry.';
      try { msg = jsonDecode(response.body)['error'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
    return ParsedResumeResult.fromJson(jsonDecode(response.body));
  }
}

// ─── ATSCategoryScore ──────────────────────────────────────────────────────
int _toInt(dynamic value) {
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}

class ATSCategoryScore {
  final int score;
  final String reasoning;
  ATSCategoryScore({required this.score, required this.reasoning});

  factory ATSCategoryScore.fromJson(Map<String, dynamic> j) => ATSCategoryScore(
    score: _toInt(j['score']),
    reasoning: j['reasoning'] ?? '',
  );
}

// ─── ATSCriticalIssue ──────────────────────────────────────────────────────
class ATSCriticalIssue {
  final String issue;
  final String fix;
  final String priority; // 'high' | 'medium' | 'low'
  ATSCriticalIssue({
    required this.issue,
    required this.fix,
    required this.priority,
  });

  factory ATSCriticalIssue.fromJson(Map<String, dynamic> j) => ATSCriticalIssue(
    issue: j['issue'] ?? '',
    fix: j['fix'] ?? '',
    priority: j['priority'] ?? 'medium',
  );
}

// ─── ATSResult ─────────────────────────────────────────────────────────────
class ATSResult {
  final int score;
  // Legacy flat lists (backward compat)
  final List<String> issues, fixes, keywords, missingKeywords;
  // New rich fields
  final Map<String, ATSCategoryScore> categories;
  final List<ATSCriticalIssue> criticalIssues;
  final List<String> matchedKeywords;
  final List<String> top3Wins;
  final List<String> top3Improvements;
  final String engine; // 'gemini' | 'llama3' | ''
  final bool cached;

  ATSResult({
    required this.score,
    required this.issues,
    required this.fixes,
    required this.keywords,
    required this.missingKeywords,
    this.categories = const {},
    this.criticalIssues = const [],
    this.matchedKeywords = const [],
    this.top3Wins = const [],
    this.top3Improvements = const [],
    this.engine = '',
    this.cached = false,
  });

  factory ATSResult.empty() => ATSResult(
    score: 0,
    issues: ['Could not analyse. Please retry.'],
    fixes: [],
    keywords: [],
    missingKeywords: [],
  );

  factory ATSResult.fromJson(Map<String, dynamic> j) {
    // Support both old schema (score) and new schema (total_score)
    final score = _toInt(j['total_score'] ?? j['score']);

    // Parse categories map
    final rawCats = j['categories'] as Map<String, dynamic>? ?? {};
    final categories = rawCats.map(
      (k, v) =>
          MapEntry(k, ATSCategoryScore.fromJson(v as Map<String, dynamic>)),
    );

    // Parse critical_issues — new schema
    final rawIssues = j['critical_issues'] as List? ?? [];
    final criticalIssues = rawIssues
        .map((e) => ATSCriticalIssue.fromJson(e as Map<String, dynamic>))
        .toList();

    // Flatten critical_issues back into legacy issue/fix lists for UI backward compat
    final legacyIssues = criticalIssues.isNotEmpty
        ? criticalIssues.map((e) => e.issue).toList()
        : List<String>.from(j['issues'] ?? []);
    final legacyFixes = criticalIssues.isNotEmpty
        ? criticalIssues.map((e) => e.fix).toList()
        : List<String>.from(j['fixes'] ?? []);

    return ATSResult(
      score: score,
      issues: legacyIssues,
      fixes: legacyFixes,
      keywords: List<String>.from(j['matched_keywords'] ?? j['keywords'] ?? []),
      missingKeywords: List<String>.from(j['missing_keywords'] ?? []),
      categories: categories,
      criticalIssues: criticalIssues,
      matchedKeywords: List<String>.from(
        j['matched_keywords'] ?? j['keywords'] ?? [],
      ),
      top3Wins: List<String>.from(j['top_3_wins'] ?? []),
      top3Improvements: List<String>.from(j['top_3_improvements'] ?? []),
      engine: j['_engine'] ?? '',
      cached: j['_cached'] == true,
    );
  }
}

class KeywordMatchResult {
  final List<String> requiredKeywords, matched, missing;
  final int matchPercentage;

  KeywordMatchResult({
    required this.requiredKeywords,
    required this.matched,
    required this.missing,
    required this.matchPercentage,
  });

  factory KeywordMatchResult.fromJson(Map<String, dynamic> j) =>
      KeywordMatchResult(
        requiredKeywords: List<String>.from(j['required_keywords'] ?? []),
        matched: List<String>.from(j['matched'] ?? []),
        missing: List<String>.from(j['missing'] ?? []),
        matchPercentage: _toInt(j['match_percentage']),
      );
}

class TailoredResumeResult {
  final String targetRole;
  final String summary;
  final List<Map<String, dynamic>> experience;
  final List<String> skills;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> certifications;
  final Map<String, dynamic> sections;
  final List<String> warnings;
  final List<Map<String, dynamic>> changes;

  TailoredResumeResult({
    required this.targetRole,
    required this.summary,
    required this.experience,
    required this.skills,
    this.projects = const [],
    this.education = const [],
    this.certifications = const [],
    this.sections = const {},
    this.warnings = const [],
    this.changes = const [],
  });

  factory TailoredResumeResult.fromJson(Map<String, dynamic> j) {
    final nestedResume =
        _asMap(j['resume']) ??
        _asMap(j['tailoredResume']) ??
        _asMap(j['tailored_resume']);
    final sections =
        _asMap(j['sections']) ?? _asMap(nestedResume?['sections']) ?? {};
    final personal = _asMap(sections['personal']) ?? {};

    final experienceSource = j['experience'] ?? sections['experience'];
    final skillsSource = j['skills'] ?? sections['skills'];
    final projectsSource = j['projects'] ?? sections['projects'];
    final educationSource = j['education'] ?? sections['education'];
    final certificationsSource =
        j['certifications'] ?? sections['certifications'];

    return TailoredResumeResult(
      targetRole: _toTextValue(
        j['targetRole'] ??
            j['target_role'] ??
            nestedResume?['targetRole'] ??
            nestedResume?['target_role'],
      ),
      summary: _toTextValue(j['summary'] ?? personal['summary']),
      experience: _mapList(experienceSource),
      skills: _stringList(skillsSource),
      projects: _mapList(projectsSource),
      education: _mapList(educationSource),
      certifications: _mapList(certificationsSource),
      sections: Map<String, dynamic>.from(sections),
      warnings: _stringList(j['warnings'] ?? nestedResume?['warnings']),
      changes: _mapList(j['changes'] ?? nestedResume?['changes']),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(_toTextValue)
      .where((text) => text.trim().isNotEmpty)
      .toList();
}

String _toTextValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return '';
}

// ─── ParsedResumeResult ─────────────────────────────────────────────────────
class ParsedResumeResult {
  final Map<String, dynamic> sections;
  final String targetRole;
  final String title;

  const ParsedResumeResult({
    required this.sections,
    required this.targetRole,
    required this.title,
  });

  factory ParsedResumeResult.fromJson(Map<String, dynamic> j) {
    final rawSections = _asMap(j['sections']) ?? {};

    // Deep-normalize personal — must be Map<String, dynamic>
    final personal = _asMap(rawSections['personal']) ?? {};

    // Deep-normalize list sections — each item must be Map<String, dynamic>
    List<Map<String, dynamic>> normMapList(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .map((item) {
            if (item is Map) return Map<String, dynamic>.from(item);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }

    // Skills must be a flat List<String> — handle both String items and Map items
    List<String> normSkills(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .map((s) {
            if (s is String) return s.trim();
            if (s is Map) {
              // e.g. {"name": "JavaScript"} → "JavaScript"
              return _toTextValue(s['name'] ?? s.values.firstOrNull).trim();
            }
            return s.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final sections = <String, dynamic>{
      'personal': Map<String, dynamic>.from(personal),
      'experience': normMapList(rawSections['experience']),
      'education': normMapList(rawSections['education']),
      'skills': normSkills(rawSections['skills']),
      'projects': normMapList(rawSections['projects']),
      'certifications': normMapList(rawSections['certifications']),
      'awards': normSkills(rawSections['awards']),   // flat strings
      'languages': normMapList(rawSections['languages']),
    };

    return ParsedResumeResult(
      sections: sections,
      targetRole: _toTextValue(j['targetRole']),
      title: _toTextValue(j['title']),
    );
  }

  int get experienceCount =>
      (sections['experience'] as List?)?.length ?? 0;
  int get skillsCount =>
      (sections['skills'] as List?)?.length ?? 0;
  String get name =>
      _toTextValue((sections['personal'] as Map?)?['name']);
  String get email =>
      _toTextValue((sections['personal'] as Map?)?['email']);
}
