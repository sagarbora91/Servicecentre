import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_role.dart';

part 'app_user.freezed.dart';

/// A staff member's profile, mirrored from `users/{uid}` (BUILD_BRIEF §5.1).
///
/// freezed value type: equality, `hashCode`, and `copyWith` are generated. The
/// Firestore mapping is custom (the doc id [uid] lives outside the data map and
/// an unrecognized role yields `null`), so [fromMap]/[toMap] are hand-written.
@freezed
abstract class AppUser with _$AppUser {
  const AppUser._();

  /// Creates a staff profile.
  const factory AppUser({
    required String uid,
    required String name,
    required UserRole role,
    required String phone,
    required bool active,
    String? email,
    String? branchId,
  }) = _AppUser;

  /// Builds an [AppUser] from a Firestore document's [uid] and [data].
  ///
  /// Returns `null` when the document has no recognizable [UserRole], so an
  /// unknown/garbled role is treated as "no access" rather than a crash.
  static AppUser? fromMap(String uid, Map<String, dynamic> data) {
    final role = UserRole.fromName(data['role'] as String?);
    if (role == null) return null;
    return AppUser(
      uid: uid,
      name: (data['name'] as String?) ?? '',
      role: role,
      phone: (data['phone'] as String?) ?? '',
      active: (data['active'] as bool?) ?? false,
      email: data['email'] as String?,
      branchId: data['branchId'] as String?,
    );
  }

  /// Serializes back to a Firestore-friendly map (excludes the doc-id [uid]).
  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role.name,
        'phone': phone,
        'active': active,
        if (email != null) 'email': email,
        if (branchId != null) 'branchId': branchId,
      };
}
