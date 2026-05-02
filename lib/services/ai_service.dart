import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    if (letter.trim().isEmpty) throw const FormatException('Empty letter in response');
    return CoverLetterResult(
      letter:    letter,
      engine:    (json['engine'] as String?) ?? 'unknown',
      wordCount: (json['wordCount'] as int?) ?? letter.trim().split(RegExp(r'\s+')).length,
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

class CoverLetterNetworkException    extends AiServiceException {
  const CoverLetterNetworkException(super.m);
}
class CoverLetterServerException     extends AiServiceException {
  const CoverLetterServerException(super.m);
}
class CoverLetterValidationException extends AiServiceException {
  const CoverLetterValidationException(super.m);
}
class CoverLetterTimeoutException    extends AiServiceException {
  const CoverLetterTimeoutException(super.m);
}


final aiServiceProvider = Provider<AIService>((ref) => AIService(
  backendUrl: dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:10000',
));

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

  Future<String> generateSummary({required String name,
      required String targetRole, required List<String> experiences,
      required List<String> skills}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/summary'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name, 'targetRole': targetRole, 
        'experiences': experiences, 'skills': skills
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
      return ATSResult.empty();
    }
    return ATSResult.fromJson(jsonDecode(response.body));
  }

  Future<KeywordMatchResult> matchJD(String resumeText, String jd) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/match-jd'),
      headers: await _getHeaders(),
      body: jsonEncode({'resumeText': resumeText, 'jd': jd}),
    );
    if (response.statusCode != 200) {
      return KeywordMatchResult(requiredKeywords: [], matched: [], missing: [], matchPercentage: 0);
    }
    return KeywordMatchResult.fromJson(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> importFromLinkedIn(String url) async {
    // Stub for LinkedIn import
    return {};
  }

  Future<CoverLetterResult> generateCoverLetter({
    required String resumeText,
    required String company,
    required String name,
    String? jd,
  }) async {
    // Client-side validation before burning an API call
    if (resumeText.trim().length < 50) {
      throw const CoverLetterValidationException(
          'Resume is too short to generate a cover letter. Please add more content first.');
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
                'The AI is taking too long. Please try again.'),
          );
    } on CoverLetterTimeoutException {
      rethrow;
    } on SocketException {
      throw const CoverLetterNetworkException(
          'No internet connection. Check your network and try again.');
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
          'Received an invalid response from the server.');
    }

    // Per-status error handling
    if (response.statusCode == 400) {
      throw CoverLetterValidationException(
          (body['error'] as String?) ?? 'Invalid request');
    }
    if (response.statusCode == 503 || response.statusCode == 502) {
      throw CoverLetterServerException(
          (body['error'] as String?) ?? 'AI service unavailable. Please try again shortly.');
    }
    if (response.statusCode != 200) {
      throw CoverLetterServerException(
          'Server error (${response.statusCode}). Please try again.');
    }

    try {
      return CoverLetterResult.fromJson(body);
    } on FormatException catch (e) {
      throw CoverLetterServerException('Could not parse cover letter: ${e.message}');
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
}

// ─── ATSCategoryScore ──────────────────────────────────────────────────────
class ATSCategoryScore {
  final int score;
  final String reasoning;
  ATSCategoryScore({required this.score, required this.reasoning});

  factory ATSCategoryScore.fromJson(Map<String, dynamic> j) => ATSCategoryScore(
    score: (j['score'] as num?)?.toInt() ?? 0,
    reasoning: j['reasoning'] ?? '',
  );
}

// ─── ATSCriticalIssue ──────────────────────────────────────────────────────
class ATSCriticalIssue {
  final String issue;
  final String fix;
  final String priority; // 'high' | 'medium' | 'low'
  ATSCriticalIssue({required this.issue, required this.fix, required this.priority});

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
    final score = (j['total_score'] ?? j['score'] ?? 0) as int;

    // Parse categories map
    final rawCats = j['categories'] as Map<String, dynamic>? ?? {};
    final categories = rawCats.map(
      (k, v) => MapEntry(k, ATSCategoryScore.fromJson(v as Map<String, dynamic>)),
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
      matchedKeywords: List<String>.from(j['matched_keywords'] ?? j['keywords'] ?? []),
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

  KeywordMatchResult({required this.requiredKeywords, required this.matched,
    required this.missing, required this.matchPercentage});

  factory KeywordMatchResult.fromJson(Map<String,dynamic> j) => KeywordMatchResult(
    requiredKeywords: List<String>.from(j['required_keywords'] ?? []),
    matched: List<String>.from(j['matched'] ?? []),
    missing: List<String>.from(j['missing'] ?? []),
    matchPercentage: j['match_percentage'] ?? 0);
}

class TailoredResumeResult {
  final String targetRole;
  final String summary;
  final List<Map<String, dynamic>> experience;
  final List<String> skills;

  TailoredResumeResult({
    required this.targetRole,
    required this.summary,
    required this.experience,
    required this.skills,
  });

  factory TailoredResumeResult.fromJson(Map<String, dynamic> j) => TailoredResumeResult(
    targetRole: j['targetRole'] ?? '',
    summary: j['summary'] ?? '',
    experience: List<Map<String, dynamic>>.from(
      (j['experience'] ?? []).map((e) => Map<String, dynamic>.from(e))),
    skills: List<String>.from(j['skills'] ?? []),
  );
}
