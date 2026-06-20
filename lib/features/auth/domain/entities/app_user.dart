import 'user_role.dart';

/// A staff member's profile, mirrored from `users/{uid}` (BUILD_BRIEF §5.1).
///
/// Hand-written immutable value type for M1. It migrates to a `freezed` model
/// in M2 when `build_runner` is introduced; the public shape is kept stable so
/// the migration is mechanical.
class AppUser {
  /// Creates a staff profile.
  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.phone,
    required this.active,
    this.email,
    this.branchId,
  });

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

  /// Firebase Auth UID; also the document id in `users/{uid}`.
  final String uid;

  /// Display name.
  final String name;

  /// Assigned role (source of truth for access).
  final UserRole role;

  /// Contact phone number.
  final String phone;

  /// Whether the account is active. Inactive accounts are denied access.
  final bool active;

  /// Sign-in email, if the account uses email/password.
  final String? email;

  /// Branch this user belongs to.
  final String? branchId;

  /// Serializes back to a Firestore-friendly map.
  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role.name,
        'phone': phone,
        'active': active,
        if (email != null) 'email': email,
        if (branchId != null) 'branchId': branchId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.uid == uid &&
          other.name == name &&
          other.role == role &&
          other.phone == phone &&
          other.active == active &&
          other.email == email &&
          other.branchId == branchId;

  @override
  int get hashCode =>
      Object.hash(uid, name, role, phone, active, email, branchId);
}
