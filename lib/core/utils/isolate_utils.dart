// lib/core/utils/isolate_utils.dart
//
// Top-level (not in a class) functions required by Flutter's compute() API.
// compute() spawns a true Dart isolate — no shared memory, completely
// off the UI thread, giving us 60 fps while heavy work runs in parallel.
//
// Rules for compute() functions:
//  - Must be top-level or static
//  - All arguments/return values must be JSON-serialisable primitives
//    (Map, List, String, int, double, bool, Uint8List, null)
//  - Cannot capture closures or reference Flutter/plugin singletons

import 'package:flutter/foundation.dart';
import '../../models/resume_model.dart';
import '../../services/pdf_service.dart';

// ─── Resume JSON parsing ──────────────────────────────────────────────────────

/// Parse a list of Firestore resume documents off the UI thread.
/// The arg is a List of Map(String, dynamic) (already decoded JSON).
List<Map<String, dynamic>> _parseResumeListIsolate(
  List<Map<String, dynamic>> rawList,
) {
  // We just return the raw maps — the ResumeModel construction
  // from primitives is cheap; this offloads the list iteration + map-copy.
  return rawList
      .map((raw) => Map<String, dynamic>.from(raw))
      .toList();
}

/// Decodes and parses a list of raw Firestore document maps off the UI thread.
Future<List<Map<String, dynamic>>> parseResumeListInBackground(
  List<Map<String, dynamic>> rawList,
) {
  return compute(_parseResumeListIsolate, rawList);
}

// ─── Resume text serialisation (for ATS check) ───────────────────────────────

/// Serialises a resume's sections into plain text for ATS analysis.
/// Runs inside an isolate so the UI thread stays free during this work.
String _serializeResumeIsolate(Map<String, dynamic> sections) {
  String str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return v.values.map(str).join(' ');
    if (v is List) return v.map(str).join(', ');
    return v.toString();
  }

  final buf = StringBuffer();
  final p = (sections['personal'] as Map?) ?? {};
  buf.writeln('${str(p['name'])}\n${str(p['email'])}\n${str(p['phone'])}');
  buf.writeln('PROFESSIONAL SUMMARY\n${str(p['summary'])}');
  buf.writeln('WORK EXPERIENCE');
  for (final e in (sections['experience'] as List? ?? [])) {
    final em = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
    final desc = str(em['description']);
    buf.writeln(
      '${str(em['title'])} at ${str(em['company'])} (${str(em['dates'])})\n'
      '${desc.length > 600 ? '${desc.substring(0, 600)}…' : desc}',
    );
  }
  buf.writeln('EDUCATION');
  for (final e in (sections['education'] as List? ?? [])) {
    final em = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
    buf.writeln(
      '${str(em['degree'])} - ${str(em['institution'])} (${str(em['year'])})',
    );
  }
  final skills = (sections['skills'] as List? ?? [])
      .map((s) => str(s))
      .where((s) => s.isNotEmpty)
      .take(60)
      .join(', ');
  buf.writeln('SKILLS\n$skills');
  for (final e in (sections['projects'] as List? ?? []).take(3)) {
    final em = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
    final desc = str(em['description']);
    buf.writeln(
      '${str(em['name'] ?? em['title'])}:'
      ' ${desc.length > 300 ? '${desc.substring(0, 300)}…' : desc}',
    );
  }
  return buf.toString();
}

/// Serialises resume sections to plain text on a background isolate.
Future<String> serializeResumeInBackground(
  Map<String, dynamic> sections,
) {
  return compute(_serializeResumeIsolate, sections);
}

// ─── PDF generation ───────────────────────────────────────────────────────────
//
// PDF generation (pdf package) does a huge amount of CPU work: it builds
// an entire widget tree in a pw.Document and then serialises it to bytes.
// We cannot send the full ResumeModel through compute() because it contains
// Firestore Timestamp objects, so we convert to a plain Map first.

/// Message envelope that can cross isolate boundaries.
class _PdfMessage {
  final Map<String, dynamic> resumeJson; // ResumeModel as plain JSON
  const _PdfMessage(this.resumeJson);
}

/// Top-level function run inside the isolate.
Future<Uint8List> _buildPdfIsolate(_PdfMessage msg) async {
  final resume = ResumeModel.fromJsonIsolate(msg.resumeJson);
  return PDFService().generatePDFBytes(resume);
}

/// Generates PDF bytes completely off the UI thread.
/// Returns the raw PDF bytes that can be saved or displayed.
Future<Uint8List> generatePDFInBackground(ResumeModel resume) {
  return compute(_buildPdfIsolate, _PdfMessage(resume.toJsonIsolate()));
}
