import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final authStateProvider = StreamProvider<User?>((ref) =>
    FirebaseAuth.instance.authStateChanges());

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  // -- Email/Password Sign Up --
  Future<UserCredential> signUpWithEmail(String email, String password,
      String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user?.updateDisplayName(name);
    await _createUserDoc(cred.user!, name);
    return cred;
  }

  // -- Email/Password Sign In --
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // -- Google Sign In --
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final cred = await _auth.signInWithCredential(credential);

    // Create user doc if first time
    final userDoc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!userDoc.exists) {
      await _createUserDoc(cred.user!, cred.user!.displayName ?? '');
    }
    return cred;
  }

  // -- Password Reset --
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // -- Sign Out --
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > const Duration(minutes: 5)) {
      throw Exception(
        'For security, please sign out, sign back in, and request deletion again.',
      );
    }

    await _db.collection('account_deletion_requests').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'requested',
    }, SetOptions(merge: true));

    await _deleteKnownUserData(user.uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security, please sign out, sign back in, and request deletion again.',
        );
      }
      rethrow;
    }
  }

  // -- Create Firestore User Document --
  Future<void> _createUserDoc(User user, String name) async {
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid, 'email': user.email, 'name': name,
      'plan': 'free', 'planExpiry': null, 'adsWatched': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // -- Update Last Active --
  Future<void> updateLastActive() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'lastActive': FieldValue.serverTimestamp()
    });
  }

  Future<void> _deleteKnownUserData(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    for (final collection in ['resumes', 'applications', 'coverLetters']) {
      final snap = await userRef.collection(collection).get();
      for (var i = 0; i < snap.docs.length; i += 450) {
        final batch = _db.batch();
        for (final doc in snap.docs.skip(i).take(450)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await userRef.delete();
  }
}
