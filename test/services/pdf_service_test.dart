import 'dart:convert';

import 'package:ats_resume_builder/models/resume_model.dart';
import 'package:ats_resume_builder/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PDFService Pro templates', () {
    const proTemplateIds = [
      'pro_elite',
      'pro_bold',
      'pro_ivy',
      'pro_startup',
      'pro_global',
    ];

    test('generate PDFs for every Pro template layout', () async {
      for (final templateId in proTemplateIds) {
        final bytes = await PDFService().generatePDFBytes(
          _resume(templateId: templateId),
        );

        expect(bytes.length, greaterThan(1000), reason: templateId);
        expect(latin1.decode(bytes.take(4).toList()), '%PDF');
      }
    });
  });
}

ResumeModel _resume({required String templateId}) {
  return ResumeModel(
    id: 'resume-$templateId',
    title: 'Pro Template Resume',
    templateId: templateId,
    colorTheme: 'indigo',
    lastEdited: DateTime(2026, 1, 1),
    sections: {
      'personal': {
        'name': 'Avery Stone',
        'title': 'Senior Product Engineer',
        'email': 'avery@example.com',
        'phone': '+1 555 0100',
        'location': 'Remote',
        'linkedin': 'linkedin.com/in/avery',
        'summary':
            'Product engineer with experience building reliable mobile and web products across startup and enterprise teams.',
      },
      'experience': [
        {
          'title': 'Senior Product Engineer',
          'company': 'Northstar Labs',
          'location': 'Remote',
          'dates': '2022 - Present',
          'description':
              '- Led Flutter app delivery for a revenue analytics product\n- Improved release quality with automated checks',
        },
      ],
      'education': [
        {
          'degree': 'B.S. Computer Science',
          'institution': 'State University',
          'year': '2020',
        },
      ],
      'skills': ['Flutter', 'Dart', 'Firebase', 'Product Strategy'],
      'projects': [
        {
          'name': 'ATS Resume Builder',
          'description': 'Built PDF export and resume tailoring workflows.',
          'link': 'example.com/resume',
        },
      ],
      'certifications': [
        {'name': 'Cloud Developer', 'issuer': 'Cloud Org', 'year': '2024'},
      ],
      'awards': [
        {'title': 'Product Excellence', 'issuer': 'Northstar Labs'},
      ],
      'languages': [
        {'language': 'English', 'level': 'Native'},
      ],
    },
  );
}
