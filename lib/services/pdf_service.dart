import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/resume_model.dart';

class PDFService {
  static const Map<String, PdfColor> _colors = {
    'indigo': PdfColor.fromInt(0xFF4F46E5),
    'blue': PdfColor.fromInt(0xFF2563EB),
    'slate': PdfColor.fromInt(0xFF475569),
    'green': PdfColor.fromInt(0xFF059669),
    'red': PdfColor.fromInt(0xFFDC2626),
    'purple': PdfColor.fromInt(0xFF7C3AED),
    'orange': PdfColor.fromInt(0xFFEA580C),
    'black': PdfColor.fromInt(0xFF111827),
  };

  pw.Document _buildClassicPdf(ResumeModel r, PdfColor color, pw.ImageProvider? photo) {
    final pdf = pw.Document();

    final p = r.sections['personal'] ?? {};
    final exp = r.sections['experience'] as List? ?? [];
    final edu = r.sections['education'] as List? ?? [];
    final skills = r.sections['skills'] as List? ?? [];
    final certs = r.sections['certifications'] as List? ?? [];
    final projs = r.sections['projects'] as List? ?? [];

    pw.Widget _sectionTitle(String title) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 13, bottom: 7),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: color, width: 1.5)),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    pw.Widget _bullets(String text) {
      if (text.isEmpty) return pw.SizedBox();
      if (!text.contains('\n')) return pw.Text(text, style: const pw.TextStyle(fontSize: 10));
      
      final items = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.map((item) {
          final cleanItem = item.replaceFirst(RegExp(r"^[*-] "), "");
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3.5, right: 6, left: 4),
                child: pw.Container(
                  width: 3,
                  height: 3,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(cleanItem, style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        }).toList(),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 14 * PdfPageFormat.mm, horizontal: 18 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        p['name'] ?? '',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color),
                      ),
                      pw.SizedBox(height: 3),
                    ],
                  ),
                ),
                if (photo != null)
                  pw.Container(
                    width: 50,
                    height: 50,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      image: pw.DecorationImage(image: photo, fit: pw.BoxFit.cover),
                    ),
                  ),
              ],
            ),
            
            // Contact
            pw.Wrap(
              spacing: 10,
              children: [
                if (p['email'] != null && p['email'].toString().isNotEmpty) pw.Text(p['email'], style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                if (p['phone'] != null && p['phone'].toString().isNotEmpty) pw.Text(p['phone'], style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                if (p['location'] != null && p['location'].toString().isNotEmpty) pw.Text(p['location'], style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                if (p['linkedin'] != null && p['linkedin'].toString().isNotEmpty) pw.Text(p['linkedin'], style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                if (p['portfolio'] != null && p['portfolio'].toString().isNotEmpty) pw.Text(p['portfolio'], style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
              ],
            ),
            pw.SizedBox(height: 14),

            // Summary
            if ((p['summary'] ?? '').isNotEmpty) ...[
              _sectionTitle('Professional Summary'),
              pw.Text(p['summary'], style: const pw.TextStyle(fontSize: 10.5)),
            ],

            // Experience
            if (exp.isNotEmpty) ...[
              _sectionTitle('Work Experience'),
              ...exp.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 9),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(e['title'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(e['dates'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '${e['company'] ?? ''}${(e['location'] ?? '').isNotEmpty ? ' | ${e['location']}' : ''}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 2),
                    _bullets(e['description'] ?? ''),
                  ],
                ),
              )).toList(),
            ],

            // Education
            if (edu.isNotEmpty) ...[
              _sectionTitle('Education'),
              ...edu.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 9),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(e['degree'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(e['year'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(e['institution'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    if ((e['gpa'] ?? '').isNotEmpty) 
                      pw.Text('GPA: ${e['gpa']}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              )).toList(),
            ],

            // Skills
            if (skills.isNotEmpty) ...[
              _sectionTitle('Skills'),
              pw.Wrap(
                spacing: 4,
                runSpacing: 4,
                children: skills.map((s) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(s.toString(), style: const pw.TextStyle(fontSize: 9.5)),
                )).toList(),
              ),
            ],

            // Projects
            if (projs.isNotEmpty) ...[
              _sectionTitle('Projects'),
              ...projs.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 9),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(e['name'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(e['dates'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    _bullets(e['description'] ?? ''),
                  ],
                ),
              )).toList(),
            ],

            // Certifications
            if (certs.isNotEmpty) ...[
              _sectionTitle('Certifications'),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: certs.map((c) => pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3.5, right: 6, left: 4),
                      child: pw.Container(
                        width: 3,
                        height: 3,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.black,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text('${c['name'] ?? ''} — ${c['issuer'] ?? ''} (${c['year'] ?? ''})', style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                )).toList(),
              ),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Document _buildModernPdf(ResumeModel r, PdfColor color, pw.ImageProvider? photo) {
    final pdf = pw.Document();

    final p = r.sections['personal'] ?? {};
    final exp = r.sections['experience'] as List? ?? [];
    final edu = r.sections['education'] as List? ?? [];
    final skills = r.sections['skills'] as List? ?? [];
    final projs = r.sections['projects'] as List? ?? [];

    pw.Widget sectionTitle(String title) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 15, bottom: 8),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );
    }

    pw.Widget bullets(String text) {
      if (text.isEmpty) return pw.SizedBox();
      if (!text.contains('\n')) return pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800));
      
      final items = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.map((item) {
          final cleanItem = item.replaceFirst(RegExp(r"^[*-] "), "");
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3.5, right: 6, left: 2),
                child: pw.Text('•', style: pw.TextStyle(color: color, fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Text(cleanItem, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              ),
            ],
          );
        }).toList(),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  (p['name'] ?? '').toUpperCase(),
                                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: 1.5),
                                ),
                                if ((p['title'] ?? '').isNotEmpty) ...[
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    p['title'],
                                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (photo != null)
                            pw.Container(
                              width: 60,
                              height: 60,
                              margin: const pw.EdgeInsets.only(left: 10),
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                image: pw.DecorationImage(image: photo, fit: pw.BoxFit.cover),
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      if ((p['summary'] ?? '').isNotEmpty) ...[
                        pw.Text(p['summary'], style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)),
                        pw.SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 1,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(left: 10),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(left: pw.BorderSide(color: PdfColors.grey300, width: 2)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (p['email'] != null && p['email'].toString().isNotEmpty) ...[
                          pw.Text('Email', style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
                          pw.Text(p['email'], style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 6),
                        ],
                        if (p['phone'] != null && p['phone'].toString().isNotEmpty) ...[
                          pw.Text('Phone', style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
                          pw.Text(p['phone'], style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 6),
                        ],
                        if (p['location'] != null && p['location'].toString().isNotEmpty) ...[
                          pw.Text('Location', style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
                          pw.Text(p['location'], style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 6),
                        ],
                        if (p['linkedin'] != null && p['linkedin'].toString().isNotEmpty) ...[
                          pw.Text('LinkedIn', style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
                          pw.Text(p['linkedin'], style: const pw.TextStyle(fontSize: 9.5)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 10),

            if (exp.isNotEmpty) ...[
              sectionTitle('Work Experience'),
              ...exp.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(e['title'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text(e['dates'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${e['company'] ?? ''}${(e['location'] ?? '').isNotEmpty ? ' | ${e['location']}' : ''}',
                      style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    bullets(e['description'] ?? ''),
                  ],
                ),
              )).toList(),
            ],

            if (edu.isNotEmpty) ...[
              sectionTitle('Education'),
              ...edu.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(e['degree'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text(e['year'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(e['institution'] ?? '', style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
                    if ((e['gpa'] ?? '').isNotEmpty)
                      pw.Text('GPA: ${e['gpa']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              )).toList(),
            ],

            if (skills.isNotEmpty) ...[
              sectionTitle('Skills'),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((s) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: color.shade(0.2)),
                  ),
                  child: pw.Text(s.toString(), style: const pw.TextStyle(fontSize: 9)),
                )).toList(),
              ),
              pw.SizedBox(height: 12),
            ],

            if (projs.isNotEmpty) ...[
              sectionTitle('Projects'),
              ...projs.map((p) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(p['title'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if ((p['link'] ?? '').isNotEmpty)
                          pw.Text(p['link'], style: pw.TextStyle(fontSize: 9, color: color)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    bullets(p['description'] ?? ''),
                  ],
                ),
              )).toList(),
            ],

            if (r.sections['certifications'] != null && (r.sections['certifications'] as List).isNotEmpty) ...[
              sectionTitle('Certifications'),
              ...(r.sections['certifications'] as List).map((c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(c['name'] ?? '', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(c['year'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              )).toList(),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Document _buildMinimalPdf(ResumeModel r, PdfColor color, pw.ImageProvider? photo) {
    final pdf = pw.Document();

    final p = r.sections['personal'] ?? {};
    final exp = r.sections['experience'] as List? ?? [];
    final edu = r.sections['education'] as List? ?? [];
    final skills = r.sections['skills'] as List? ?? [];

    final projs = r.sections['projects'] as List? ?? [];
    final certs = r.sections['certifications'] as List? ?? [];

    pw.Widget sectionTitle(String title) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            color: PdfColors.black,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      );
    }

    pw.Widget bullets(String text) {
      if (text.isEmpty) return pw.SizedBox();
      if (!text.contains('\n')) return pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900));
      
      final items = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.map((item) {
          final cleanItem = item.replaceFirst(RegExp(r"^[*-] "), "");
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3.5, right: 6, left: 0),
                child: pw.Text('-', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Text(cleanItem, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900, lineSpacing: 1.2)),
              ),
            ],
          );
        }).toList(),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 20 * PdfPageFormat.mm, horizontal: 25 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  if (photo != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        image: pw.DecorationImage(image: photo, fit: pw.BoxFit.cover),
                      ),
                    ),
                  pw.Text(
                    (p['name'] ?? '').toUpperCase(),
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.normal, letterSpacing: 4),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Wrap(
                    spacing: 12,
                    alignment: pw.WrapAlignment.center,
                    children: [
                      if (p['email'] != null && p['email'].toString().isNotEmpty) pw.Text(p['email'], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      if (p['phone'] != null && p['phone'].toString().isNotEmpty) pw.Text(p['phone'], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      if (p['location'] != null && p['location'].toString().isNotEmpty) pw.Text(p['location'], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      if (p['linkedin'] != null && p['linkedin'].toString().isNotEmpty) pw.Text(p['linkedin'], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            if ((p['summary'] ?? '').isNotEmpty) ...[
              pw.Text(p['summary'], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800, lineSpacing: 1.5), textAlign: pw.TextAlign.justify),
              pw.SizedBox(height: 10),
            ],

            if (exp.isNotEmpty) ...[
              sectionTitle('Experience'),
              ...exp.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(e['title'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(e['dates'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${e['company'] ?? ''}${(e['location'] ?? '').isNotEmpty ? ', ${e['location']}' : ''}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.SizedBox(height: 6),
                    bullets(e['description'] ?? ''),
                  ],
                ),
              )).toList(),
            ],

            if (edu.isNotEmpty) ...[
              sectionTitle('Education'),
              ...edu.map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(e['degree'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(e['institution'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                        ],
                      ),
                    ),
                    pw.Text(e['year'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              )).toList(),
            ],

            if (skills.isNotEmpty) ...[
              sectionTitle('Skills'),
              pw.Text(
                skills.join('  •  '),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800, lineSpacing: 1.5),
              ),
            ],

            if (projs.isNotEmpty) ...[
              sectionTitle('Projects'),
              ...projs.map((pr) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(pr['title'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if ((pr['link'] ?? '').isNotEmpty)
                          pw.Text(pr['link'], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    bullets(pr['description'] ?? ''),
                  ],
                ),
              )).toList(),
            ],

            if (certs.isNotEmpty) ...[
              sectionTitle('Certifications'),
              ...certs.map((c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(c['name'] ?? '', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(c['year'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              )).toList(),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  Future<pw.Document> _buildPdf(ResumeModel resume, PdfColor color) async {
    pw.ImageProvider? photo;
    final photoUrl = resume.sections['personal']?['photoUrl'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      try {
        photo = await networkImage(photoUrl);
      } catch (e) {
        // ignore if it fails to load
      }
    }

    switch (resume.templateId) {
      case 'modern':
        return _buildModernPdf(resume, color, photo);
      case 'minimal':
        return _buildMinimalPdf(resume, color, photo);
      case 'classic':
      default:
        return _buildClassicPdf(resume, color, photo);
    }
  }

  Future<File> generatePDF(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = await _buildPdf(resume, color);
    final name = resume.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    
    final bytes = await pdf.save();

    // Try external (Downloads) first, fall back to internal
    Directory? dir;
    try {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }

    final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Uint8List> generatePDFBytes(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = await _buildPdf(resume, color);
    return await pdf.save();
  }

  Future<void> printResume(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = await _buildPdf(resume, color);
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}

