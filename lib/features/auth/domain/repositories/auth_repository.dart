import '../../../../core/errors/result.dart';
import '../entities/app_user.dart';

/// Contract for authentication and the current user's profile.
///
/// Lives in `domain`, so it has no Firebase imports; the implementation in
/// `data` adapts Firebase Auth + Firestore to this interface.
abstract interface class AuthRepository {
  /// Emits the signed-in user's UID, or `null` when signed out. Fires on every
  /// sign-in/sign-out so route guards can react.
  Stream<String?> authStateChanges();

  /// The current UID, or `null` if signed out. Synchronous convenience for
  /// redirects.
  String? get currentUid;

  /// Signs in with [email] and [password]. Returns `Ok(null)` on success or an
  /// [Err] with an `AuthFailure` describing why it failed.
  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Signs the current user out.
  Future<Result<void>> signOut();

  /// Watches the `users/{uid}` profile. Emits `null` when the document is
  /// missing or its role is unrecognized.
  Stream<AppUser?> watchUser(String uid);
}
