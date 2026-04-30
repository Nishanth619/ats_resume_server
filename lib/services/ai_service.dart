import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final aiServiceProvider = Provider<AIService>((ref) => AIService(
  backendUrl: dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:3000',
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

  Future<ATSResult> checkATS(String resumeText, {String? targetJD}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/ats-check'),
      headers: await _getHeaders(),
      body: jsonEncode({'resumeText': resumeText, 'targetJD': targetJD}),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        final err = jsonDecode(response.body)['error'];
        throw Exception(err);
      }
      return ATSResult(score: 50, issues: ['Could not analyse'], fixes: [], keywords: [], missingKeywords: []);
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

  Future<String> generateCoverLetter({required String resumeText,
      required String jd, required String company,
      required String name}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/cover-letter'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'resumeText': resumeText, 'jd': jd, 
        'company': company, 'name': name
      }),
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return jsonDecode(response.body)['letter'];
  }
}

class ATSResult {
  final int score;
  final List<String> issues, fixes, keywords, missingKeywords;

  ATSResult({required this.score, required this.issues, required this.fixes,
    required this.keywords, required this.missingKeywords});

  factory ATSResult.fromJson(Map<String,dynamic> j) => ATSResult(
    score: j['score'] ?? 0,
    issues: List<String>.from(j['issues'] ?? []),
    fixes: List<String>.from(j['fixes'] ?? []),
    keywords: List<String>.from(j['keywords'] ?? []),
    missingKeywords: List<String>.from(j['missing_keywords'] ?? []));
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
