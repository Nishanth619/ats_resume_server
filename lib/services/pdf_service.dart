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

  pw.Document _buildNativePdf(ResumeModel r, PdfColor color) {
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
            // Name
            pw.Text(
              p['name'] ?? '',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 3),
            
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

  Future<File> generatePDF(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = _buildNativePdf(resume, color);
    final dir = await getApplicationDocumentsDirectory();
    final name = resume.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    
    final bytes = await pdf.save();
    final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Uint8List> generatePDFBytes(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = _buildNativePdf(resume, color);
    return await pdf.save();
  }

  Future<void> printResume(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = _buildNativePdf(resume, color);
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}

