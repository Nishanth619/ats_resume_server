import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

export '../services/auth_service.dart';

final userDataProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).userStream(user.uid);
});

final applicationsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).applicationsStream(uid);
});

