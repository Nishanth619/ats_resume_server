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
    return ApplicationModel(
      id: id,
      company: map['company'] ?? '',
      role: map['role'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.value == (map['status'] ?? 'applied'),
        orElse: () => ApplicationStatus.applied,
      ),
      appliedAt: map['appliedAt'] != null
          ? DateTime.parse(map['appliedAt'].toString())
          : DateTime.now(),
      notes: map['notes'] ?? '',
      jobUrl: map['jobUrl'] ?? '',
    );
  }
}
