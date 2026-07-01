import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';

/// Appends one entry to the append-only `activityLog` collection (CLAUDE.md #9:
/// every write logs to `activityLog`).
///
/// Lives in the `data`/infrastructure layer (it touches Firestore directly).
/// [actor] is the acting uid; [action] is a short verb (e.g. `job.deliver`);
/// [entity]/[entityId] identify the affected document; [before]/[after] capture
/// the relevant change. `at` is stamped with `serverTimestamp()`.
Future<void> writeActivityLog(
  FirebaseFirestore firestore, {
  required String actor,
  required String action,
  required String entity,
  required String entityId,
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
}) {
  return firestore.collection(Collections.activityLog).add(<String, dynamic>{
    'actor': actor,
    'action': action,
    'entity': entity,
    'entityId': entityId,
    if (before != null) 'before': before,
    if (after != null) 'after': after,
    'at': FieldValue.serverTimestamp(),
  });
}
