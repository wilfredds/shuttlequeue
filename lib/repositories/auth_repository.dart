import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lahat ng auth operations dumadaan dito — walang FirebaseAuth calls
/// mula sa UI. Ang Firestore dito ay para lang sa users/{uid} profile doc.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Register ng bagong Queue Master: Auth account + users/{uid} profile doc.
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) return;

    await user.updateDisplayName(displayName);

    // role: "qm" — naka-reserve para sa future roles (hal. player accounts sa v2).
    await _db.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'email': email,
      'role': 'qm',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => _auth.signOut();
}
