import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/audit/data/repositories/firestore_activity_repository.dart';

void main() {
  test('watchRecent streams entries newest-first, capped at the limit',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreActivityRepository(firestore: firestore);

    await firestore.collection('activityLog').add(<String, dynamic>{
      'actor': 'u1',
      'action': 'job.create',
      'entity': 'jobs',
      'entityId': 'j1',
      'at': Timestamp.fromDate(DateTime.utc(2026, 7, 1, 9)),
    });
    await firestore.collection('activityLog').add(<String, dynamic>{
      'actor': 'u2',
      'action': 'job.deliver',
      'entity': 'jobs',
      'entityId': 'j1',
      'at': Timestamp.fromDate(DateTime.utc(2026, 7, 1, 12)),
    });

    final entries = await repo.watchRecent(10).first;

    expect(entries, hasLength(2));
    // Newest first.
    expect(entries.first.action, 'job.deliver');
    expect(entries.first.actor, 'u2');
    expect(entries.last.action, 'job.create');
  });

  test('respects the limit', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreActivityRepository(firestore: firestore);
    for (var i = 0; i < 5; i++) {
      await firestore.collection('activityLog').add(<String, dynamic>{
        'actor': 'u',
        'action': 'x',
        'entity': 'e',
        'entityId': 'id',
        'at': Timestamp.fromDate(DateTime.utc(2026, 7, 1, i)),
      });
    }

    final entries = await repo.watchRecent(3).first;
    expect(entries, hasLength(3));
  });
}
