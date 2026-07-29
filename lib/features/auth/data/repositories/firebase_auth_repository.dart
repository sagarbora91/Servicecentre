import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by Firebase Auth (sign-in) and Cloud Firestore (the
/// `users/{uid}` profile that holds the role).
class FirebaseAuthRepository implements AuthRepository {
  /// Creates the repository with injected Firebase services so tests can pass
  /// mocks/fakes.
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(AuthFailure(_reasonFor(e.code), e.message ?? e.code));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return const Ok(null);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Stream<AppUser?> watchUser(String uid) => _firestore
      .collection(Collections.users)
      .doc(uid)
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return AppUser.fromMap(uid, data);
  });

  AuthFailureReason _reasonFor(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'invalid-email':
      case 'wrong-password':
      case 'user-not-found':
        return AuthFailureReason.invalidCredentials;
      case 'user-disabled':
        return AuthFailureReason.userDisabled;
      case 'network-request-failed':
        return AuthFailureReason.network;
      case 'too-many-requests':
        return AuthFailureReason.tooManyRequests;
      default:
        return AuthFailureReason.unknown;
    }
  }
}
