/// A read view of one `activityLog/{id}` entry (BUILD_BRIEF.md §5.1) for the
/// audit-trail screen. Plain immutable value; the `data` layer maps Firestore
/// documents to it so `domain` stays Firebase-free.
class ActivityEntry {
  /// Creates an activity entry.
  const ActivityEntry({
    required this.id,
    required this.actor,
    required this.action,
    required this.entity,
    required this.entityId,
    this.at,
  });

  /// The document id.
  final String id;

  /// The acting user's uid.
  final String actor;

  /// The action performed (e.g. `job.deliver`, `payment.record.cash`).
  final String action;

  /// The affected collection (e.g. `jobs`).
  final String entity;

  /// The affected document id.
  final String entityId;

  /// When it happened (UTC), or `null` if the timestamp is not yet resolved.
  final DateTime? at;
}
