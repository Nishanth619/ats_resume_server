import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

// ─── Provider ──────────────────────────────────────────────────────────────────
final linkedInImportServiceProvider = Provider<LinkedInImportService>((ref) {
  return LinkedInImportService(
    Dio(),
    baseUrl: dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:10000',
  );
});

// ─── LinkedIn ZIP Import Service ───────────────────────────────────────────────
class LinkedInImportService {
  final Dio _dio;
  final String baseUrl;

  LinkedInImportService(this._dio, {required this.baseUrl});

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  /// Opens a file picker for a LinkedIn data export ZIP,
  /// uploads it to the backend, and returns the parsed resume data.
  Future<Map<String, dynamic>?> importFromZip() async {
    // 1. Open file picker filtered to ZIP
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.bytes == null) throw Exception('Could not read file');

    // 2. Get auth headers
    final headers = await _authHeaders();

    // 3. Upload to backend
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType: DioMediaType('application', 'zip'),
      ),
    });

    final response = await _dio.post(
      '$baseUrl/api/linkedin/import-zip',
      data: formData,
      options: Options(
        headers: {
          ...headers,
          // Don't set Content-Type manually — Dio sets the boundary automatically
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['resume'] as Map<String, dynamic>;
    }

    throw Exception(response.data['error'] ?? 'Import failed');
  }
}

// ─── LinkedIn OAuth Service ────────────────────────────────────────────────────
class LinkedInOAuthService {
  final Dio _dio;
  final String baseUrl;

  LinkedInOAuthService(this._dio, {required this.baseUrl});

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Gets the OAuth URL from the backend. The UI layer is responsible
  /// for launching it in a browser and listening for the deep link.
  Future<String> getOAuthUrl() async {
    final response = await _dio.get(
      '$baseUrl/api/linkedin/auth-url',
      options: Options(headers: await _authHeaders()),
    );
    if (response.statusCode != 200) {
      throw Exception(response.data['error'] ?? 'Could not generate OAuth URL');
    }
    return response.data['url'] as String;
  }

  /// Decodes the resume data received via the deep link callback URI.
  /// Call this after receiving the atsresumebuilder://linkedin-callback URI.
  Map<String, dynamic>? parseCallback(Uri callbackUri) {
    final error = callbackUri.queryParameters['error'];
    if (error != null) throw Exception('LinkedIn login failed: $error');

    final resumeJson = callbackUri.queryParameters['resume'];
    if (resumeJson == null) return null;

    return jsonDecode(Uri.decodeComponent(resumeJson)) as Map<String, dynamic>;
  }
}

final linkedInOAuthServiceProvider = Provider<LinkedInOAuthService>((ref) {
  return LinkedInOAuthService(
    Dio(),
    baseUrl: dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:10000',
  );
});
