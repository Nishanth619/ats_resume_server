import 'package:flutter_test/flutter_test.dart';
import 'package:ats_resume_builder/models/resume_model.dart';

void main() {
  group('ResumeModel Tests', () {
    test('fromJson and toJson should handle standard data', () {
      final json = {
        'id': '123',
        'title': 'Software Engineer',
        'templateId': 'modern',
        'colorTheme': 'indigo',
        'sections': {
          'personal': {
            'name': 'John Doe',
            'email': 'john@example.com',
          },
          'experience': [
            {
              'title': 'Developer',
              'company': 'Tech Corp',
            }
          ],
        },
      };

      final model = ResumeModel.fromJson(json);

      expect(model.id, '123');
      expect(model.title, 'Software Engineer');
      expect(model.templateId, 'modern');
      expect(model.sections['personal']?['name'], 'John Doe');
      expect((model.sections['experience'] as List).first['company'], 'Tech Corp');

      final tojson = model.toJson();
      expect(tojson['id'], '123');
      expect(tojson['title'], 'Software Engineer');
      expect(tojson['sections']['personal']['email'], 'john@example.com');
    });

    // We skip testing copy() since ResumeModel doesn't currently implement it in this version.
  });
}
