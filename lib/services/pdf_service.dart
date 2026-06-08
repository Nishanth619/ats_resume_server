import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/resume_model.dart';
import '../models/resume_template.dart';

class PDFService {
  static final Map<String, PdfColor> _colors = {
    'indigo': PdfColor.fromInt(0xFF4F46E5),
    'blue': PdfColor.fromInt(0xFF2563EB),
    'slate': PdfColor.fromInt(0xFF475569),
    'green': PdfColor.fromInt(0xFF059669),
    'red': PdfColor.fromInt(0xFFDC2626),
    'purple': PdfColor.fromInt(0xFF7C3AED),
    'orange': PdfColor.fromInt(0xFFEA580C),
    'black': PdfColor.fromInt(0xFF111827),
  };

  List<Map<String, dynamic>> _normMapList(dynamic raw, String defaultKey) {
    if (raw is! List) return [];
    return raw.map((item) {
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{defaultKey: item?.toString() ?? ''};
    }).toList();
  }

  _ResumeContent _extract(ResumeModel r) {
    return _ResumeContent(
      personal: r.sections['personal'] as Map? ?? {},
      experience: _normMapList(r.sections['experience'], 'title'),
      education: _normMapList(r.sections['education'], 'degree'),
      skills: (r.sections['skills'] as List? ?? [])
          .map((s) => s.toString())
          .toList(),
      projects: _normMapList(r.sections['projects'], 'name')
          .map(_normaliseProject)
          .toList(),
      certifications: _normMapList(r.sections['certifications'], 'name'),
      awards: _normMapList(r.sections['awards'], 'title'),
      languages: _normMapList(r.sections['languages'], 'language'),
    );
  }

  Map<String, dynamic> _normaliseProject(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    m['name'] ??= m['title'] ?? '';
    return m;
  }

  pw.Widget _bullets(String text, PdfColor bulletColor) {
    if (text.isEmpty) return pw.SizedBox();
    final lines = text
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[•\*\-] ?'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length == 1) {
      return pw.Text(
        lines.first,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines
          .map(
            (item) => pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(
                    top: 4,
                    right: 6,
                    left: 2,
                  ),
                  // Small filled square — renders correctly on ALL PDF viewers.
                  // Do NOT use pw.Text('•') — U+2022 is outside WinAnsi and
                  // renders as a cross/X on Helvetica/Times. Do NOT use
                  // pw.BoxShape.circle — it can also render as X on some viewers.
                  child: pw.Container(
                    width: 4,
                    height: 4,
                    color: bulletColor,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }


  pw.Document _buildClassicPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();

    pw.Widget sectionTitle(String title) => pw.Container(
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          vertical: 14 * PdfPageFormat.mm,
          horizontal: 18 * PdfPageFormat.mm,
        ),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      c.personal['name'] ?? '',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if ((c.personal['title'] ?? '').isNotEmpty)
                      pw.Text(
                        c.personal['title'],
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              if (photo != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    image: pw.DecorationImage(
                      image: photo,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
          _contactRow(c.personal),
          pw.SizedBox(height: 14),
          if ((c.personal['summary'] ?? '').isNotEmpty) ...[
            sectionTitle('Professional Summary'),
            pw.Text(
              c.personal['summary'],
              style: const pw.TextStyle(fontSize: 10.5),
            ),
          ],
          if (c.experience.isNotEmpty) ...[
            sectionTitle('Work Experience'),
            ..._expEntries(c.experience, color, PdfColors.black),
          ],
          if (c.education.isNotEmpty) ...[
            sectionTitle('Education'),
            ..._eduEntries(c.education),
          ],
          if (c.skills.isNotEmpty) ...[
            sectionTitle('Skills'),
            _skillsWrap(c.skills, chipBorderColor: PdfColors.grey300),
          ],
          if (c.projects.isNotEmpty) ...[
            sectionTitle('Projects'),
            ..._projectEntries(c.projects, color),
          ],
          if (c.certifications.isNotEmpty) ...[
            sectionTitle('Certifications'),
            ..._certEntries(c.certifications),
          ],
          if (c.awards.isNotEmpty) ...[
            sectionTitle('Awards & Achievements'),
            ..._awardEntries(c.awards),
          ],
          if (c.languages.isNotEmpty) ...[
            sectionTitle('Languages'),
            _languagesWrap(c.languages),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildModernPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();

    pw.Widget sectionTitle(String title) => pw.Container(
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18 * PdfPageFormat.mm),
        build: (ctx) => [
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
                                (c.personal['name'] ?? '').toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 26,
                                  fontWeight: pw.FontWeight.bold,
                                  color: color,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              if ((c.personal['title'] ?? '').isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  c.personal['title'],
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.grey700,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
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
                              image: pw.DecorationImage(
                                image: photo,
                                fit: pw.BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    if ((c.personal['summary'] ?? '').isNotEmpty)
                      pw.Text(
                        c.personal['summary'],
                        style: const pw.TextStyle(
                          fontSize: 10,
                          lineSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.only(left: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.grey300, width: 2),
                    ),
                  ),
                  child: _contactSidebar(c.personal, color),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          if (c.experience.isNotEmpty) ...[
            sectionTitle('Work Experience'),
            ..._expEntries(c.experience, color, PdfColors.black),
          ],
          if (c.education.isNotEmpty) ...[
            sectionTitle('Education'),
            ..._eduEntries(c.education, accentColor: color),
          ],
          if (c.skills.isNotEmpty) ...[
            sectionTitle('Skills'),
            _skillsWrap(
              c.skills,
              chipBorderColor: _lightenPdfColor(color, 0.2),
              chipFill: PdfColors.grey100,
            ),
            pw.SizedBox(height: 12),
          ],
          if (c.projects.isNotEmpty) ...[
            sectionTitle('Projects'),
            ..._projectEntries(c.projects, color),
          ],
          if (c.certifications.isNotEmpty) ...[
            sectionTitle('Certifications'),
            ..._certEntries(c.certifications, showYear: true),
          ],
          if (c.awards.isNotEmpty) ...[
            sectionTitle('Awards & Achievements'),
            ..._awardEntries(c.awards, accentColor: color),
          ],
          if (c.languages.isNotEmpty) ...[
            sectionTitle('Languages'),
            _languagesWrap(
              c.languages,
              borderColor: _lightenPdfColor(color, 0.2),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildMinimalPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();

    pw.Widget sectionTitle(String title) => pw.Container(
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          vertical: 20 * PdfPageFormat.mm,
          horizontal: 25 * PdfPageFormat.mm,
        ),
        build: (ctx) => [
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
                      image: pw.DecorationImage(
                        image: photo,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),
                pw.Text(
                  (c.personal['name'] ?? '').toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.normal,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 12,
                  alignment: pw.WrapAlignment.center,
                  children: [
                    for (final key in [
                      'email',
                      'phone',
                      'location',
                      'linkedin',
                    ])
                      if ((c.personal[key] ?? '').isNotEmpty)
                        pw.Text(
                          c.personal[key],
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if ((c.personal['summary'] ?? '').isNotEmpty) ...[
            pw.Text(
              c.personal['summary'],
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
                lineSpacing: 1.5,
              ),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 10),
          ],
          if (c.experience.isNotEmpty) ...[
            sectionTitle('Experience'),
            ..._expEntriesMinimal(c.experience),
          ],
          if (c.education.isNotEmpty) ...[
            sectionTitle('Education'),
            ..._eduEntriesMinimal(c.education),
          ],
          if (c.skills.isNotEmpty) ...[
            sectionTitle('Skills'),
            pw.Text(
              c.skills.join('  |  '),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
                lineSpacing: 1.5,
              ),
            ),
          ],
          if (c.projects.isNotEmpty) ...[
            sectionTitle('Projects'),
            ..._projectEntriesMinimal(c.projects),
          ],
          if (c.certifications.isNotEmpty) ...[
            sectionTitle('Certifications'),
            ..._certEntries(c.certifications),
          ],
          if (c.awards.isNotEmpty) ...[
            sectionTitle('Awards & Achievements'),
            ..._awardEntries(c.awards),
          ],
          if (c.languages.isNotEmpty) ...[
            sectionTitle('Languages'),
            pw.Text(
              c.languages
                  .map((l) => '${l["language"] ?? ""} (${l["level"] ?? ""})')
                  .join('  |  '),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
                lineSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildProElitePdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();
    final dark = PdfColor.fromInt(0xFF111827);
    final cyan = PdfColor.fromInt(0xFF06B6D4);

    pw.Widget sectionTitle(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 7),
      child: pw.Row(
        children: [
          pw.Container(width: 24, height: 2, color: cyan),
          pw.SizedBox(width: 8),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: dark,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
            color: dark,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (photo != null) ...[
                  pw.Container(
                    width: 58,
                    height: 58,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: cyan, width: 2),
                      image: pw.DecorationImage(image: photo),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (c.personal['name'] ?? '').toString().toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 23,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      if ((c.personal['title'] ?? '').toString().isNotEmpty)
                        pw.Text(
                          c.personal['title'].toString(),
                          style: pw.TextStyle(
                            color: cyan,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: cyan, width: 1),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(3),
                    ),
                  ),
                  child: pw.Text(
                    'ELITE PROFILE',
                    style: pw.TextStyle(
                      color: cyan,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(26, 24, 26, 26),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 154,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF8FAFC),
                    border: pw.Border(
                      left: pw.BorderSide(color: cyan, width: 3),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _sideBlock('Contact', _contactSidebar(c.personal, cyan)),
                      if (c.skills.isNotEmpty)
                        _sideBlock(
                          'Core Skills',
                          _skillsWrap(
                            c.skills.take(12).toList(),
                            chipBorderColor: _lightenPdfColor(cyan, 0.35),
                            chipFill: PdfColors.white,
                          ),
                        ),
                      if (c.education.isNotEmpty)
                        _sideBlock(
                          'Education',
                          pw.Column(children: _eduEntries(c.education)),
                        ),
                      if (c.languages.isNotEmpty)
                        _sideBlock('Languages', _languagesWrap(c.languages)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 22),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if ((c.personal['summary'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        sectionTitle('Executive Summary'),
                        pw.Text(
                          c.personal['summary'].toString(),
                          style: const pw.TextStyle(
                            fontSize: 10.5,
                            lineSpacing: 1.6,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                      if (c.experience.isNotEmpty) ...[
                        sectionTitle('Leadership Experience'),
                        ..._expEntries(c.experience, cyan, dark),
                      ],
                      if (c.projects.isNotEmpty) ...[
                        sectionTitle('Signature Projects'),
                        ..._projectEntries(c.projects, cyan),
                      ],
                      if (c.awards.isNotEmpty) ...[
                        sectionTitle('Recognition'),
                        ..._awardEntries(c.awards, accentColor: cyan),
                      ],
                      if (c.certifications.isNotEmpty) ...[
                        sectionTitle('Credentials'),
                        ..._certEntries(c.certifications, showYear: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildProBoldPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();
    final red = PdfColor.fromInt(0xFFDC2626);
    final ink = PdfColor.fromInt(0xFF18181B);

    pw.Widget sectionTitle(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      color: ink,
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 7, height: 720, color: red),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                (c.personal['name'] ?? '').toString(),
                                style: pw.TextStyle(
                                  color: ink,
                                  fontSize: 30,
                                  fontWeight: pw.FontWeight.bold,
                                  lineSpacing: 0.8,
                                ),
                              ),
                              if ((c.personal['title'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                pw.Container(
                                  margin: const pw.EdgeInsets.only(top: 5),
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  color: red,
                                  child: pw.Text(
                                    c.personal['title'].toString(),
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (photo != null)
                          pw.Container(
                            width: 58,
                            height: 58,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: red, width: 3),
                              image: pw.DecorationImage(image: photo),
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    _contactRow(c.personal),
                    if ((c.personal['summary'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      sectionTitle('Impact Statement'),
                      pw.Text(
                        c.personal['summary'].toString(),
                        style: const pw.TextStyle(
                          fontSize: 10.5,
                          lineSpacing: 1.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                    if (c.experience.isNotEmpty) ...[
                      sectionTitle('Experience'),
                      ..._timelineExpEntries(c.experience, red),
                    ],
                    if (c.skills.isNotEmpty) ...[
                      sectionTitle('Skills'),
                      _skillsWrap(
                        c.skills,
                        chipBorderColor: red,
                        chipFill: PdfColor.fromInt(0xFFFFF1F2),
                      ),
                    ],
                    if (c.projects.isNotEmpty) ...[
                      sectionTitle('Projects'),
                      ..._projectEntries(c.projects, red),
                    ],
                    if (c.education.isNotEmpty) ...[
                      sectionTitle('Education'),
                      ..._eduEntries(c.education, accentColor: red),
                    ],
                    if (c.certifications.isNotEmpty) ...[
                      sectionTitle('Certifications'),
                      ..._certEntries(c.certifications, showYear: true),
                    ],
                    if (c.awards.isNotEmpty) ...[
                      sectionTitle('Awards'),
                      ..._awardEntries(c.awards, accentColor: red),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildProIvyPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();
    final navy = PdfColor.fromInt(0xFF0F2942);
    final gold = PdfColor.fromInt(0xFFB45309);

    pw.Widget sectionTitle(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 17, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(height: 0.7, color: gold),
          pw.SizedBox(height: 3),
          pw.Text(
            title.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: navy,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Container(height: 0.7, color: gold),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          vertical: 22 * PdfPageFormat.mm,
          horizontal: 24 * PdfPageFormat.mm,
        ),
        build: (ctx) => [
          pw.Center(
            child: pw.Column(
              children: [
                if (photo != null)
                  pw.Container(
                    width: 54,
                    height: 54,
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: gold, width: 1.2),
                      image: pw.DecorationImage(image: photo),
                    ),
                  ),
                pw.Text(
                  (c.personal['name'] ?? '').toString().toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: navy,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                if ((c.personal['title'] ?? '').toString().isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    c.personal['title'].toString(),
                    style: pw.TextStyle(
                      color: gold,
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
                pw.SizedBox(height: 10),
                _contactRow(c.personal),
              ],
            ),
          ),
          if ((c.personal['summary'] ?? '').toString().isNotEmpty) ...[
            sectionTitle('Profile'),
            pw.Text(
              c.personal['summary'].toString(),
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(
                fontSize: 10.5,
                lineSpacing: 1.5,
                color: PdfColors.grey800,
              ),
            ),
          ],
          if (c.experience.isNotEmpty) ...[
            sectionTitle('Professional Appointments'),
            ..._expEntries(c.experience, gold, navy),
          ],
          if (c.education.isNotEmpty) ...[
            sectionTitle('Education'),
            ..._eduEntries(c.education, accentColor: navy),
          ],
          if (c.projects.isNotEmpty) ...[
            sectionTitle('Selected Work'),
            ..._projectEntries(c.projects, gold),
          ],
          if (c.skills.isNotEmpty) ...[
            sectionTitle('Competencies'),
            pw.Text(
              c.skills.join('  |  '),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
                lineSpacing: 1.5,
              ),
            ),
          ],
          if (c.certifications.isNotEmpty) ...[
            sectionTitle('Credentials'),
            ..._certEntries(c.certifications, showYear: true),
          ],
          if (c.awards.isNotEmpty) ...[
            sectionTitle('Honors'),
            ..._awardEntries(c.awards, accentColor: gold),
          ],
          if (c.languages.isNotEmpty) ...[
            sectionTitle('Languages'),
            _languagesWrap(c.languages),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildProStartupPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();
    final violet = PdfColor.fromInt(0xFF7C3AED);
    final indigo = PdfColor.fromInt(0xFF4F46E5);
    final panel = PdfColor.fromInt(0xFFF5F3FF);

    pw.Widget sectionTitle(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: violet,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );

    pw.Widget card(String title, List<pw.Widget> children) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE9D5FF)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [sectionTitle(title), ...children],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18 * PdfPageFormat.mm),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: panel,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Row(
              children: [
                if (photo != null) ...[
                  pw.Container(
                    width: 56,
                    height: 56,
                    decoration: pw.BoxDecoration(
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      image: pw.DecorationImage(image: photo),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        c.personal['name'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 24,
                          color: indigo,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((c.personal['title'] ?? '').toString().isNotEmpty)
                        pw.Text(
                          c.personal['title'].toString(),
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: violet,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      _contactRow(c.personal),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((c.personal['summary'] ?? '').toString().isNotEmpty)
            card('Founder Pitch', [
              pw.Text(
                c.personal['summary'].toString(),
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  lineSpacing: 1.5,
                  color: PdfColors.grey800,
                ),
              ),
            ]),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (c.experience.isNotEmpty)
                      card(
                        'Build History',
                        _expEntries(c.experience, violet, indigo),
                      ),
                    if (c.projects.isNotEmpty)
                      card(
                        'Launches & Projects',
                        _projectEntries(c.projects, violet),
                      ),
                    if (c.awards.isNotEmpty)
                      card(
                        'Wins',
                        _awardEntries(c.awards, accentColor: violet),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (c.skills.isNotEmpty)
                      card('Stack', [
                        _skillsWrap(
                          c.skills,
                          chipBorderColor: violet,
                          chipFill: panel,
                        ),
                      ]),
                    if (c.education.isNotEmpty)
                      card(
                        'Education',
                        _eduEntries(c.education, accentColor: indigo),
                      ),
                    if (c.certifications.isNotEmpty)
                      card(
                        'Certs',
                        _certEntries(c.certifications, showYear: true),
                      ),
                    if (c.languages.isNotEmpty)
                      card('Languages', [_languagesWrap(c.languages)]),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Document _buildProGlobalPdf(
    _ResumeContent c,
    PdfColor color,
    pw.ImageProvider? photo,
  ) {
    final pdf = pw.Document();
    final teal = PdfColor.fromInt(0xFF0F766E);
    final deep = PdfColor.fromInt(0xFF134E4A);

    pw.Widget sectionTitle(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 15, bottom: 7),
      child: pw.Row(
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: deep,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(height: 1, color: teal)),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 24),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: teal, width: 1.2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (c.personal['name'] ?? '').toString().toUpperCase(),
                        style: pw.TextStyle(
                          color: deep,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      if ((c.personal['title'] ?? '').toString().isNotEmpty)
                        pw.Text(
                          c.personal['title'].toString(),
                          style: pw.TextStyle(
                            color: teal,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      _contactRow(c.personal),
                    ],
                  ),
                ),
                if (photo != null)
                  pw.Container(
                    width: 54,
                    height: 54,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      image: pw.DecorationImage(image: photo),
                    ),
                  ),
              ],
            ),
          ),
          pw.Container(height: 8, color: deep),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if ((c.personal['summary'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        sectionTitle('Global Profile'),
                        pw.Text(
                          c.personal['summary'].toString(),
                          style: const pw.TextStyle(
                            fontSize: 10.5,
                            lineSpacing: 1.5,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                      if (c.experience.isNotEmpty) ...[
                        sectionTitle('International Experience'),
                        ..._expEntries(c.experience, teal, deep),
                      ],
                      if (c.projects.isNotEmpty) ...[
                        sectionTitle('Cross-Market Projects'),
                        ..._projectEntries(c.projects, teal),
                      ],
                      if (c.awards.isNotEmpty) ...[
                        sectionTitle('Recognition'),
                        ..._awardEntries(c.awards, accentColor: teal),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF0FDFA),
                      border: pw.Border(
                        top: pw.BorderSide(color: teal, width: 3),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (c.skills.isNotEmpty)
                          _sideBlock(
                            'Capabilities',
                            _skillsWrap(
                              c.skills,
                              chipBorderColor: teal,
                              chipFill: PdfColors.white,
                            ),
                          ),
                        if (c.education.isNotEmpty)
                          _sideBlock(
                            'Education',
                            pw.Column(
                              children: _eduEntries(
                                c.education,
                                accentColor: deep,
                              ),
                            ),
                          ),
                        if (c.certifications.isNotEmpty)
                          _sideBlock(
                            'Certifications',
                            pw.Column(
                              children: _certEntries(
                                c.certifications,
                                showYear: true,
                              ),
                            ),
                          ),
                        if (c.languages.isNotEmpty)
                          _sideBlock(
                            'Languages',
                            _languagesWrap(c.languages, borderColor: teal),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _sideBlock(String title, pw.Widget child) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 6),
        child,
      ],
    ),
  );

  List<pw.Widget> _timelineExpEntries(List exp, PdfColor accentColor) => exp
      .map<pw.Widget>(
        (e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Container(width: 1.2, height: 58, color: accentColor),
                ],
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            e['title'] ?? '',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Text(
                          e['dates'] ?? '',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '${e['company'] ?? ''}${(e['location'] ?? '').isNotEmpty ? ' | ${e['location']}' : ''}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: accentColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    _bullets(e['description'] ?? '', accentColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
      .toList();

  pw.Widget _contactRow(Map p) => pw.Wrap(
    spacing: 10,
    children: [
      for (final key in ['email', 'phone', 'location', 'linkedin', 'portfolio'])
        if ((p[key] ?? '').isNotEmpty)
          pw.Text(
            p[key],
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
          ),
    ],
  );

  pw.Widget _contactSidebar(Map p, PdfColor color) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final entry in {
        'email': 'Email',
        'phone': 'Phone',
        'location': 'Location',
        'linkedin': 'LinkedIn',
        'portfolio': 'Portfolio',
      }.entries)
        if ((p[entry.key] ?? '').isNotEmpty) ...[
          pw.Text(
            entry.value,
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(p[entry.key], style: const pw.TextStyle(fontSize: 9.5)),
          pw.SizedBox(height: 6),
        ],
    ],
  );

  List<pw.Widget> _expEntries(
    List exp,
    PdfColor accentColor,
    PdfColor titleColor,
  ) => exp
      .map<pw.Widget>(
        (e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 9),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    e['title'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    e['dates'] ?? '',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                '${e['company'] ?? ''}${(e['location'] ?? '').isNotEmpty ? ' | ${e['location']}' : ''}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: accentColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              _bullets(e['description'] ?? '', accentColor),
            ],
          ),
        ),
      )
      .toList();

  List<pw.Widget> _expEntriesMinimal(List exp) => exp
      .map<pw.Widget>(
        (e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    e['title'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    e['dates'] ?? '',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${e['company'] ?? ''}${(e['location'] ?? '').isNotEmpty ? ', ${e['location']}' : ''}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey800,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 6),
              _bullets(e['description'] ?? '', PdfColors.grey700),
            ],
          ),
        ),
      )
      .toList();

  List<pw.Widget> _eduEntries(List edu, {PdfColor? accentColor}) => edu
      .map<pw.Widget>(
        (e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 9),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    e['degree'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    e['year'] ?? '',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                e['institution'] ?? '',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: accentColor ?? PdfColors.grey800,
                  fontWeight: accentColor != null
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
              if ((e['gpa'] ?? '').isNotEmpty)
                pw.Text(
                  'GPA: ${e['gpa']}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey800,
                  ),
                ),
            ],
          ),
        ),
      )
      .toList();

  List<pw.Widget> _eduEntriesMinimal(List edu) => edu
      .map<pw.Widget>(
        (e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      e['degree'] ?? '',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      e['institution'] ?? '',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                e['year'] ?? '',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      )
      .toList();

  pw.Widget _skillsWrap(
    List<String> skills, {
    PdfColor? chipBorderColor,
    PdfColor? chipFill,
  }) => pw.Wrap(
    spacing: 4,
    runSpacing: 4,
    children: skills
        .map(
          (s) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: chipFill ?? PdfColors.grey200,
              border: pw.Border.all(
                color: chipBorderColor ?? PdfColors.grey300,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(s, style: const pw.TextStyle(fontSize: 9.5)),
          ),
        )
        .toList(),
  );

  List<pw.Widget> _projectEntries(
    List<Map<String, dynamic>> projs,
    PdfColor color,
  ) => projs
      .map<pw.Widget>(
        (e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 9),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    e['name'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if ((e['dates'] ?? '').isNotEmpty)
                    pw.Text(
                      e['dates'],
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
              if ((e['link'] ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  e['link'],
                  style: pw.TextStyle(fontSize: 9, color: color),
                ),
              ],
              pw.SizedBox(height: 2),
              _bullets(e['description'] ?? '', color),
            ],
          ),
        ),
      )
      .toList();

  List<pw.Widget> _projectEntriesMinimal(List<Map<String, dynamic>> projs) =>
      projs
          .map<pw.Widget>(
            (e) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        e['name'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((e['link'] ?? '').isNotEmpty)
                        pw.Text(
                          e['link'],
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  _bullets(e['description'] ?? '', PdfColors.grey700),
                ],
              ),
            ),
          )
          .toList();

  List<pw.Widget> _certEntries(List certs, {bool showYear = false}) => certs
      .map<pw.Widget>(
        (c) => showYear
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${c['name'] ?? ''} - ${c['issuer'] ?? ''}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      c['year'] ?? '',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              )
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        top: 4,
                        right: 6,
                        left: 4,
                      ),
                      // Small filled square — same fix as _bullets().
                      child: pw.Container(
                        width: 3,
                        height: 3,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        '${c['name'] ?? ''} - ${c['issuer'] ?? ''} (${c['year'] ?? ''})',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
      )
      .toList();

  List<pw.Widget> _awardEntries(List awards, {PdfColor? accentColor}) => awards
      .map<pw.Widget>(
        (a) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    a['title'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    a['date'] ?? '',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              if ((a['issuer'] ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  a['issuer'],
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    color: accentColor ?? PdfColors.grey800,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
              if ((a['description'] ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  a['description'],
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ],
          ),
        ),
      )
      .toList();

  pw.Widget _languagesWrap(List langs, {PdfColor? borderColor}) => pw.Wrap(
    spacing: 12,
    runSpacing: 4,
    children: langs.map<pw.Widget>((l) {
      final text = '${l["language"] ?? ""} (${l["level"] ?? ""})';
      return borderColor != null
          ? pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
            )
          : pw.Text(text, style: const pw.TextStyle(fontSize: 10));
    }).toList(),
  );

  PdfColor _lightenPdfColor(PdfColor c, double amount) {
    return PdfColor(
      c.red + (1.0 - c.red) * amount,
      c.green + (1.0 - c.green) * amount,
      c.blue + (1.0 - c.blue) * amount,
    );
  }

  Future<pw.Document> _buildPdf(ResumeModel resume, PdfColor color) async {
    pw.ImageProvider? photo;

    final content = _extract(resume);
    switch (resume.templateId) {
      case 'pro_elite':
        return _buildProElitePdf(content, color, photo);
      case 'pro_bold':
        return _buildProBoldPdf(content, color, photo);
      case 'pro_ivy':
        return _buildProIvyPdf(content, color, photo);
      case 'pro_startup':
        return _buildProStartupPdf(content, color, photo);
      case 'pro_global':
        return _buildProGlobalPdf(content, color, photo);
    }

    final layout = templateLayoutForId(resume.templateId);
    switch (layout) {
      case TemplateLayout.modern:
        return _buildModernPdf(content, color, photo);
      case TemplateLayout.minimal:
        return _buildMinimalPdf(content, color, photo);
      case TemplateLayout.classic:
        return _buildClassicPdf(content, color, photo);
    }
  }

  Future<Uint8List> generatePDFBytes(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = await _buildPdf(resume, color);
    return pdf.save();
  }

  Future<File> generatePDF(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = await _buildPdf(resume, color);
    final bytes = await pdf.save();

    final safeName = resume.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    late final Directory saveDir;
    if (!kIsWeb && Platform.isAndroid) {
      saveDir = await _resolveAndroidSaveDir();
    } else {
      saveDir = await getApplicationDocumentsDirectory();
    }

    final file = File('${saveDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Directory> _resolveAndroidSaveDir() async {
    final externalDir = await getExternalStorageDirectory();
    return externalDir ?? getApplicationDocumentsDirectory();
  }

  /// Saves already-generated PDF bytes to disk and returns the File.
  /// Use this when bytes were generated by [generatePDFInBackground] on an
  /// isolate — the isolate does the heavy CPU work, then you call this on
  /// the main thread to write the file.
  Future<File> savePDFBytesToFile(ResumeModel resume, Uint8List bytes) async {
    final safeName = resume.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    late final Directory saveDir;
    if (!kIsWeb && Platform.isAndroid) {
      saveDir = await _resolveAndroidSaveDir();
    } else {
      saveDir = await getApplicationDocumentsDirectory();
    }

    final file = File('${saveDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> printResume(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? PdfColor.fromInt(0xFF4F46E5);
    final pdf = await _buildPdf(resume, color);
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }
}

class _ResumeContent {
  final Map personal;
  final List experience;
  final List education;
  final List<String> skills;
  final List<Map<String, dynamic>> projects;
  final List certifications;
  final List awards;
  final List languages;

  const _ResumeContent({
    required this.personal,
    required this.experience,
    required this.education,
    required this.skills,
    required this.projects,
    required this.certifications,
    required this.awards,
    required this.languages,
  });
}
