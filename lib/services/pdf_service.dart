import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/resume_model.dart';

class PDFService {
  static const Map<String,String> _colors = {
    'indigo':'#4F46E5','blue':'#2563EB','slate':'#475569',
    'green':'#059669','red':'#DC2626','purple':'#7C3AED',
    'orange':'#EA580C','black':'#111827',
  };

  String _buildHTML(ResumeModel r, String color) {
    final p = r.sections['personal'] ?? {};
    final exp = r.sections['experience'] as List? ?? [];
    final edu = r.sections['education'] as List? ?? [];
    final skills = r.sections['skills'] as List? ?? [];
    final certs = r.sections['certifications'] as List? ?? [];
    final projs = r.sections['projects'] as List? ?? [];

    String _bullets(String text) {
      if (text.isEmpty) return '';
      if (!text.contains('\n')) return '<p style="margin:0">$text</p>';
      final items = text.split('\n').where((l) => l.trim().isNotEmpty)
          .map((l) => '<li>${l.replaceFirst(RegExp(r"^[*-] "), "")}</li>').join();
      return '<ul style="margin:2px 0;padding-left:16px">$items</ul>';
    }

    return '''<!DOCTYPE html><html><head><meta charset="UTF-8">
<style>
* { margin:0;padding:0;box-sizing:border-box; }
body { font-family:Arial,Helvetica,sans-serif;font-size:11pt;line-height:1.4; color:#000;max-width:210mm;padding:14mm 18mm; }
.name { font-size:22pt;font-weight:bold;color:$color;margin-bottom:3px; }
.contact { font-size:9.5pt;color:#333;margin-bottom:14px; }
.contact span { margin-right:10px; }
h2 { font-size:12pt;font-weight:bold;color:$color;text-transform:uppercase; letter-spacing:.5px;border-bottom:1.5px solid $color; padding-bottom:2px;margin:13px 0 7px 0; }
.entry { margin-bottom:9px; }
.row { display:flex;justify-content:space-between;align-items:baseline; }
.title { font-weight:bold;font-size:11pt; }
.dates { font-size:10pt;color:#555; }
.sub { font-size:10pt;color:#333;margin-bottom:2px; }
.desc { font-size:10pt; }
.desc ul { padding-left:15px; }
.desc li { margin-bottom:1px; }
.skill { display:inline-block;background:#f0f0f0;border:1px solid #ddd; padding:1px 6px;border-radius:3px;font-size:9.5pt;margin:2px; }
</style></head><body>
<div class="name">${p['name']??''}</div>
<div class="contact">
${p['email']!=null?'<span>${p['email']}</span>':''}
${p['phone']!=null?'<span>${p['phone']}</span>':''}
${p['location']!=null?'<span>${p['location']}</span>':''}
${p['linkedin']!=null?'<span>${p['linkedin']}</span>':''}
${p['portfolio']!=null?'<span>${p['portfolio']}</span>':''}
</div>
${(p['summary']??'').isNotEmpty?'<h2>Professional Summary</h2><p style="font-size:10.5pt">${p['summary']}</p>':''}
${exp.isNotEmpty?'<h2>Work Experience</h2>'+exp.map((e)=> '<div class="entry"><div class="row"><span class="title">${e['title']??''}</span><span class="dates">${e['dates']??''}</span></div><div class="sub">${e['company']??''}${(e['location']??'').isNotEmpty?' | ${e['location']}':''}</div><div class="desc">${_bullets(e['description']??'')}</div></div>').join():''}
${edu.isNotEmpty?'<h2>Education</h2>'+edu.map((e)=> '<div class="entry"><div class="row"><span class="title">${e['degree']??''}</span><span class="dates">${e['year']??''}</span></div><div class="sub">${e['institution']??''}</div>${(e['gpa']??'').isNotEmpty?'<div class="sub">GPA: ${e['gpa']}</div>':''}</div>').join():''}
${skills.isNotEmpty?'<h2>Skills</h2><div>'+skills.map((s)=>'<span class="skill">$s</span>').join()+'</div>':''}
${projs.isNotEmpty?'<h2>Projects</h2>'+projs.map((e)=> '<div class="entry"><div class="row"><span class="title">${e['name']??''}</span><span class="dates">${e['dates']??''}</span></div><div class="desc">${_bullets(e['description']??'')}</div></div>').join():''}
${certs.isNotEmpty?'<h2>Certifications</h2><ul style="padding-left:16px;font-size:10pt">'+ certs.map((c)=>'<li>${c['name']??''} — ${c['issuer']??''} (${c['year']??''})</li>').join()+'</ul>':''}
</body></html>''';
  }

  Future<File> generatePDF(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? '#4F46E5';
    final html = _buildHTML(resume, color);
    final dir = await getApplicationDocumentsDirectory();
    final name = resume.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    
    final bytes = await Printing.convertHtml(
      format: PdfPageFormat.a4,
      html: html,
    );
    
    final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> printResume(ResumeModel resume) async {
    final color = _colors[resume.colorTheme] ?? '#4F46E5';
    final html = _buildHTML(resume, color);
    await Printing.layoutPdf(
      onLayout: (fmt) => Printing.convertHtml(format: fmt, html: html));
  }
}
