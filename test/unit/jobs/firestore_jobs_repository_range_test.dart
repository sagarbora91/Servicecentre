import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';

import '../../support/jobs_harness.dart';

void main() {
  test('jobsInRange returns only jobs created within the window', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreJobsRepository(firestore: firestore);
    final due = DateTime.utc(2026, 8, 1);

    await firestore.collection('jobs').doc('a').set(
          jobDoc(
            id: 'a',
            jobNo: '2607-0001',
            customerId: 'c1',
            status: 'received',
            dueAt: due,
            createdAt: DateTime.utc(2026, 7, 1, 10),
          ),
        );
    await firestore.collection('jobs').doc('b').set(
          jobDoc(
            id: 'b',
            jobNo: '2607-0002',
            customerId: 'c1',
            status: 'received',
            dueAt: due,
            createdAt: DateTime.utc(2026, 7, 5, 10), // outside the window
          ),
        );

    final result = await repo.jobsInRange(
      'b1',
      DateTime.utc(2026, 7, 1),
      DateTime.utc(2026, 7, 2),
    );

    expect(result.valueOrNull!.map((j) => j.id), ['a']);
  });
}
