import 'package:ats_resume_builder/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ATSResult', () {
    test('parses normalized ATS response with numeric strings', () {
      final result = ATSResult.fromJson({
        'total_score': '82',
        'categories': {
          'keyword_match': {'score': '18', 'reasoning': 'Strong match'},
        },
        'critical_issues': [
          {
            'issue': 'Missing metrics',
            'fix': 'Add supported outcomes',
            'priority': 'high',
          },
        ],
        'matched_keywords': ['Flutter', 'Firebase'],
        'missing_keywords': ['CI/CD'],
        'top_3_wins': ['Clear structure'],
        'top_3_improvements': ['Add metrics'],
        '_engine': 'gemini',
      });

      expect(result.score, 82);
      expect(result.categories['keyword_match']?.score, 18);
      expect(result.issues, ['Missing metrics']);
      expect(result.fixes, ['Add supported outcomes']);
      expect(result.matchedKeywords, ['Flutter', 'Firebase']);
      expect(result.engine, 'gemini');
    });
  });

  group('KeywordMatchResult', () {
    test('parses normalized job description match response', () {
      final result = KeywordMatchResult.fromJson({
        'required_keywords': ['Dart', 'REST APIs'],
        'matched': ['Dart'],
        'missing': ['REST APIs'],
        'match_percentage': '50',
      });

      expect(result.requiredKeywords, ['Dart', 'REST APIs']);
      expect(result.matched, ['Dart']);
      expect(result.missing, ['REST APIs']);
      expect(result.matchPercentage, 50);
    });
  });

  group('TailoredResumeResult', () {
    test('parses tailored sections and audit fields', () {
      final result = TailoredResumeResult.fromJson({
        'targetRole': 'Flutter Developer',
        'summary': 'Mobile engineer with Flutter experience.',
        'experience': [
          {
            'title': 'Developer',
            'company': 'Acme',
            'description': 'Built Flutter screens.',
          },
        ],
        'skills': ['Flutter', 'Firebase'],
        'warnings': ['Kubernetes not supported by resume evidence'],
        'changes': [
          {
            'section': 'summary',
            'before': 'Old',
            'after': 'New',
            'reason': 'Aligned to JD',
          },
        ],
      });

      expect(result.targetRole, 'Flutter Developer');
      expect(result.experience.single['company'], 'Acme');
      expect(result.skills, ['Flutter', 'Firebase']);
      expect(result.warnings.single, contains('Kubernetes'));
      expect(result.changes.single['section'], 'summary');
    });
  });
}
