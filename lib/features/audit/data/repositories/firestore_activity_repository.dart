import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/repositories/activity_repository.dart';

/// [ActivityRepository] backed by Cloud Firestore.
class FirestoreActivityRepository implements ActivityRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreActivityRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ActivityEntry>> watchRecent(int limit) => _firestore
      .collection(Collections.activityLog)
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) _fromDoc(d.id, d.data())]);

  ActivityEntry _fromDoc(String id, Map<String, dynamic> data) => ActivityEntry(
        id: id,
        actor: FirestoreConvert.toStr(data['actor']),
        action: FirestoreConvert.toStr(data['action']),
        entity: FirestoreConvert.toStr(data['entity']),
        entityId: FirestoreConvert.toStr(data['entityId']),
        at: FirestoreConvert.toDateTime(data['at']),
      );
}
