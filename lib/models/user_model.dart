class UserModel {
  final String uid;
  final String email;
  final String name;
  final String plan;
  final DateTime? planExpiry;
  final int adsWatched;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.plan = 'free',
    this.planExpiry,
    this.adsWatched = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      plan: data['plan'] ?? 'free',
      planExpiry: data['planExpiry']?.toDate(),
      adsWatched: data['adsWatched'] ?? 0,
    );
  }
}
