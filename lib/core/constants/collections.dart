/// Firestore collection names, kept in one place so paths are not stringly
/// duplicated across the data layer (BUILD_BRIEF.md §5.1).
abstract final class Collections {
  const Collections._();

  /// `users/{uid}` — staff accounts and their roles.
  static const String users = 'users';

  /// `activityLog/{id}` — append-only audit trail for every write.
  static const String activityLog = 'activityLog';
}
