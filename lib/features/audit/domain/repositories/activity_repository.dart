// Single-method repository PORT for reading the audit trail. Disable the
// pedantic one-member-abstract hint (it does not fit the port idiom).
// ignore_for_file: one_member_abstracts
import '../entities/activity_entry.dart';

/// Contract for reading the append-only `activityLog` audit trail. Lives in
/// `domain` (no Firebase imports); the `data` implementation adapts Firestore.
abstract interface class ActivityRepository {
  /// Streams the most recent [limit] activity entries, newest first.
  Stream<List<ActivityEntry>> watchRecent(int limit);
}
