import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/firebase/activity_log.dart';

void main() {
  group('writeActivityLog', () {
    test('appends one entry with the given fields and a timestamp', () async {
      final firestore = FakeFirebaseFirestore();

      await writeActivityLog(
        firestore,
        actor: 'u1',
        action: 'job.deliver',
        entity: 'jobs',
        entityId: 'j1',
        after: <String, dynamic>{'status': 'delivered'},
      );

      final logs = await firestore.collection('activityLog').get();
      expect(logs.docs, hasLength(1));
      final data = logs.docs.first.data();
      expect(data['actor'], 'u1');
      expect(data['action'], 'job.deliver');
      expect(data['entity'], 'jobs');
      expect(data['entityId'], 'j1');
      expect(data['after'], <String, dynamic>{'status': 'delivered'});
      expect(data['at'], isA<Timestamp>());
    });

    test('omits before/after when not provided', () async {
      final firestore = FakeFirebaseFirestore();

      await writeActivityLog(
        firestore,
        actor: 'u1',
        action: 'job.move.in_repair',
        entity: 'jobs',
        entityId: 'j1',
      );

      final data =
          (await firestore.collection('activityLog').get()).docs.first.data();
      expect(data.containsKey('before'), isFalse);
      expect(data.containsKey('after'), isFalse);
    });
  });
}
