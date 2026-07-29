import '../../../../core/errors/result.dart';
import '../entities/app_user.dart';

/// Contract for managing staff accounts (`users/{uid}`), backing the owner-only
/// "manage staff" admin.
///
/// Lives in `domain`, so it has no Firebase imports; the implementation in
/// `data` adapts Cloud Firestore to this interface. Role/permission enforcement
/// also lives in `firestore.rules` — these methods never replace those checks.
abstract interface class UsersRepository {
  /// Streams the staff of [branchId], ordered by [AppUser.name].
  ///
  /// Emits both active and inactive members so the admin can re-activate a
  /// disabled account. Documents with an unrecognized role are skipped (see
  /// [AppUser.fromMap]).
  Stream<List<AppUser>> watchStaff(String branchId);

  /// Reads a single staff member by [uid].
  ///
  /// Returns `Err(NotFoundFailure)` when the document is missing or its role is
  /// unrecognized.
  Future<Result<AppUser>> getUser(String uid);

  /// Creates or updates `users/{uid}` from [user] (via [AppUser.toMap]).
  ///
  /// Writes are merged, so an existing document is updated in place rather than
  /// overwritten. Audit fields are maintained automatically: `updatedAt` is set
  /// on every call, while `createdAt`/`createdBy` are stamped only when the
  /// document does not yet exist. [by] is the acting user's uid.
  Future<Result<void>> upsertStaff(AppUser user, {required String by});

  /// Flips the `active` flag on `users/[uid]` to [active], bumping `updatedAt`
  /// and recording [by] as `updatedBy`.
  ///
  /// [by] is the acting user's uid. Returns `Err(NotFoundFailure)` when the
  /// document does not exist.
  Future<Result<void>> setActive(
    String uid, {
    required bool active,
    required String by,
  });
}
