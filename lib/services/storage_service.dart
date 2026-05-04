import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
  final _storage = FirebaseStorage.instance;

  // Upload Generated PDF
  Future<String> uploadResumePDF(String uid, String resumeId, File pdfFile) async {
    final ref = _storage.ref('resumes/$uid/$resumeId.pdf');
    final task = await ref.putFile(pdfFile,
        SettableMetadata(contentType: 'application/pdf'));
    return task.ref.getDownloadURL();
  }

  // Upload Profile Photo
  Future<String> uploadProfilePhoto(String uid, File imageFile) async {
    // Use users/{uid}/profile.jpg path — must match Firebase Storage rules
    final ref = _storage.ref('users/$uid/profile.jpg');
    final task = await ref.putFile(
      imageFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uid': uid},
      ),
    );
    return task.ref.getDownloadURL();
  }

  // Generate Shareable Link (30-day expiry handled server-side)
  Future<String> getShareableLink(String uid, String resumeId) async {
    final ref = _storage.ref('resumes/$uid/$resumeId.pdf');
    return ref.getDownloadURL();
  }

  // Delete Resume PDF
  Future<void> deletePDF(String uid, String resumeId) async {
    try {
      await _storage.ref('resumes/$uid/$resumeId.pdf').delete();
    } catch (_) {}
  }

  // Upload with Progress Stream
  Stream<double> uploadWithProgress(String uid, String resumeId, File file) async* {
    final ref = _storage.ref('resumes/$uid/$resumeId.pdf');
    final task = ref.putFile(file);
    await for (final snap in task.snapshotEvents) {
      yield snap.bytesTransferred / snap.totalBytes;
    }
  }
}
