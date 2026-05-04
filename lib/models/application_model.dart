import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus { applied, interview, offer, rejected }

extension ApplicationStatusExtension on ApplicationStatus {
  String get value => toString().split('.').last;
}

class ApplicationModel {
  final String id;
  final String company;
  final String role;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final String notes;
  final String jobUrl;

  ApplicationModel({
    required this.id,
    required this.company,
    required this.role,
    required this.status,
    required this.appliedAt,
    this.notes = '',
    this.jobUrl = '',
  });

  factory ApplicationModel.fromMap(String id, Map<String, dynamic> map) {
    // Safely parse the appliedAt field which can be:
    // - A Firestore Timestamp object (most common)
    // - A String (from JSON serialization)
    // - null (when serverTimestamp hasn't resolved yet)
    DateTime parsedDate;
    final raw = map['appliedAt'];
    if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else if (raw is DateTime) {
      parsedDate = raw;
    } else if (raw is String && raw.isNotEmpty) {
      parsedDate = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ApplicationModel(
      id: id,
      company: map['company'] ?? '',
      role: map['role'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.value == (map['status'] ?? 'applied'),
        orElse: () => ApplicationStatus.applied,
      ),
      appliedAt: parsedDate,
      notes: map['notes'] ?? '',
      jobUrl: map['jobUrl'] ?? '',
    );
  }
}
