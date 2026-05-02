import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/resume_model.dart';
import '../models/user_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // -- USER --
  Stream<UserModel?> userStream(String uid) =>
      _db.collection('users').doc(uid).snapshots()
          .map((s) => s.exists ? UserModel.fromMap(s.data()!) : null);

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  // -- RESUMES --
  Stream<List<ResumeModel>> resumesStream(String uid) =>
      _db.collection('users').doc(uid).collection('resumes')
          .orderBy('lastEdited', descending: true)
          .snapshots()
          .map((s) => s.docs.map((doc) => ResumeModel.fromJson({'id': doc.id, ...doc.data()})).toList());

  Stream<ResumeModel> resumeStream(String uid, String resumeId) =>
      _db.collection('users').doc(uid).collection('resumes').doc(resumeId)
          .snapshots()
          .map((s) => ResumeModel.fromJson({'id': s.id, ...s.data()!}));

  Future<String> createResume(String uid, ResumeModel resume) async {
    final ref = await _db.collection('users').doc(uid)
        .collection('resumes').add(resume.toJson()..remove('id'));
    return ref.id;
  }

  Future<void> saveResume(String uid, ResumeModel resume) =>
      _db.collection('users').doc(uid).collection('resumes').doc(resume.id)
          .set(resume.toJson()..remove('id'), SetOptions(merge: true));

  Future<void> deleteResume(String uid, String resumeId) =>
      _db.collection('users').doc(uid).collection('resumes').doc(resumeId).delete();

  Future<void> saveVersionSnapshot(String uid, String resumeId, Map<String, dynamic> snapshot) async {
    await _db.collection('users').doc(uid).collection('resumes').doc(resumeId)
        .update({
          'versions': FieldValue.arrayUnion([{
            'data': snapshot,
            'savedAt': Timestamp.now(),
          }])
        });
  }

  // -- APPLICATIONS (For Job Tracker) --
  Stream<List<Map<String, dynamic>>> applicationsStream(String uid) =>
      _db.collection('users').doc(uid).collection('applications')
          .orderBy('appliedAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<String> addApplication(String uid, Map<String, dynamic> data) async {
    final ref = await _db.collection('users').doc(uid)
        .collection('applications').add({
          ...data,
          'appliedAt': FieldValue.serverTimestamp()
        });
    return ref.id;
  }

  Future<void> updateApplicationStatus(String uid, String appId, String status) async {
    await _db.collection('users').doc(uid).collection('applications')
        .doc(appId).update({'status': status});
  }
  
  Future<void> updateApplicationNotes(String uid, String appId, String notes) async {
    await _db.collection('users').doc(uid).collection('applications')
        .doc(appId).update({'notes': notes});
  }

  Future<void> deleteApplication(String uid, String appId) =>
      _db.collection('users').doc(uid).collection('applications')
          .doc(appId).delete();

  // -- COVER LETTERS --

  /// Saves a generated cover letter. Never overwrites — always creates a new doc.
  /// Returns the new Firestore document ID.
  Future<String> saveCoverLetter({
    required String uid,
    required String letter,
    required String company,
    String engine  = 'unknown',
    int    wordCount = 0,
  }) async {
    try {
      final ref = await _db
          .collection('users')
          .doc(uid)
          .collection('coverLetters')
          .add({
        'letter':    letter,
        'company':   company,
        'engine':    engine,
        'wordCount': wordCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Permission denied. Please log in again.');
        case 'unavailable':
          throw Exception(
              'Could not save — no connection. Your letter is still shown above.');
        default:
          throw Exception('Failed to save cover letter: ${e.message}');
      }
    }
  }

  /// Updates the letter text (e.g. after user edits) without creating a new doc.
  Future<void> updateCoverLetter({
    required String uid,
    required String docId,
    required String letter,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('coverLetters')
          .doc(docId)
          .update({
        'letter':    letter,
        'wordCount': letter.trim().split(RegExp(r'\s+')).length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to update cover letter: ${e.message}');
    }
  }


  Stream<List<Map<String,dynamic>>> coverLettersStream(String uid) =>
      _db.collection('users').doc(uid).collection('coverLetters')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  // -- TEMPLATES --
  Future<List<Map<String,dynamic>>> getTemplates() async {
    final snap = await _db.collection('templates').get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  // -- ATS RATE LIMITS --
  Future<bool> checkAndIncrementATSLimit(String uid, bool isPro) async {
    if (isPro) return true;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final ref = _db.collection('ats_limits').doc('${uid}_$today');
    return _db.runTransaction((txn) async {
      final doc = await txn.get(ref);
      final count = (doc.data()?['count'] ?? 0) as int;
      if (count >= 3) return false;
      txn.set(ref, {'count': count + 1}, SetOptions(merge: true));
      return true;
    });
  }
}
