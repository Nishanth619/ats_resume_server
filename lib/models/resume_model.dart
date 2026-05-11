import 'package:cloud_firestore/cloud_firestore.dart';

class ResumeModel {
  final String id;
  final String title;
  final String templateId;
  final String colorTheme;
  final int atsScore;
  final Map<String, dynamic> sections;
  final String targetRole;
  final String targetJD;
  final DateTime lastEdited;
  final int downloadCount;

  ResumeModel({
    required this.id,
    required this.title,
    this.templateId = 'classic',
    this.colorTheme = 'blue',
    this.atsScore = 0,
    required this.sections,
    this.targetRole = '',
    this.targetJD = '',
    required this.lastEdited,
    this.downloadCount = 0,
  });

  factory ResumeModel.fromJson(Map<String, dynamic> data) {
    return ResumeModel(
      id: data['id'] ?? '',
      title: data['title'] ?? 'Untitled Resume',
      templateId: data['templateId'] ?? 'classic',
      colorTheme: data['colorTheme'] ?? 'blue',
      atsScore: data['atsScore'] ?? 0,
      sections: data['sections'] ?? {},
      targetRole: data['targetRole'] ?? '',
      targetJD: data['targetJD'] ?? '',
      lastEdited: (data['lastEdited'] as Timestamp?)?.toDate() ?? DateTime.now(),
      downloadCount: data['downloadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'templateId': templateId,
      'colorTheme': colorTheme,
      'atsScore': atsScore,
      'sections': sections,
      'targetRole': targetRole,
      'targetJD': targetJD,
      'lastEdited': Timestamp.fromDate(lastEdited),
      'downloadCount': downloadCount,
      // 'versions' is now a subcollection — not stored in this document
    };
  }

  Map<String, dynamic> toFirestore() => toJson();

  factory ResumeModel.fromFirestore(DocumentSnapshot doc) {
    return ResumeModel.fromJson({'id': doc.id, ...doc.data() as Map<String, dynamic>});
  }
}
