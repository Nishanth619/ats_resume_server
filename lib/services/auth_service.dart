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
}
