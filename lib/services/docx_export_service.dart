import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../models/resume_model.dart';

final docxServiceProvider = Provider<DocxExportService>(
  (ref) => DocxExportService(),
);

class DocxExportService {
  final _dio = Dio();

  String get _backendUrl => AppConfig.backendUrl;

  /// Export resume as .docx — returns File path on success.
  /// [onProgress] callback receives 0.0 → 1.0 as download progresses.
  Future<File> exportToDocx(
    ResumeModel resume, {
    void Function(double progress)? onProgress,
  }) async {
    // 1. Get auth token
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not authenticated');

    // 2. Build safe filename
    final safeName = resume.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_');

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${safeName}_Resume.docx';

    // 3. POST resume data, stream response bytes to file
    await _dio
        .post(
          '$_backendUrl/api/export/docx',
          data: resume.toFirestore(),
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            responseType: ResponseType.bytes,
            followRedirects: true,
          ),
          onReceiveProgress: (received, total) {
            if (total > 0 && onProgress != null) {
              onProgress(received / total);
            }
          },
        )
        .then((response) async {
          if (response.statusCode != 200) {
            throw Exception('Server error: ${response.statusCode}');
          }
          final file = File(filePath);
          await file.writeAsBytes(response.data as List<int>);
        });

    return File(filePath);
  }

  /// Open the downloaded .docx file in the device's default app
  Future<void> openDocx(File file) async {
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Could not open file: ${result.message}');
    }
  }
}
