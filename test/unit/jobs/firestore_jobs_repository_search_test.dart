import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';

void main() {
  group('FirestoreJobsRepository search reads', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreJobsRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreJobsRepository(firestore: firestore);
    });

    Future<void> seed({
      required String id,
      String jobNo = '2606-0001',
      String customerId = 'c1',
      String branchId = 'b1',
      String? watchId,
    }) =>
        firestore.collection('jobs').doc(id).set(<String, dynamic>{
          'jobNo': jobNo,
          'customerId': customerId,
          'branchId': branchId,
          if (watchId != null) 'watchId': watchId,
        });

    group('searchJobsByJobNo', () {
      test('matches a jobNo prefix within the branch', () async {
        await seed(id: 'j1', jobNo: '2606-0001');
        await seed(id: 'j2', jobNo: '2606-0099');
        await seed(id: 'j3', jobNo: '2701-0001');

        final result = await repo.searchJobsByJobNo('b1', '2606');

        expect(result.valueOrNull!.map((j) => j.id).toSet(), {'j1', 'j2'});
      });

      test('excludes other branches and empty queries', () async {
        await seed(id: 'j1', jobNo: '2606-0001');
        await seed(id: 'j2', jobNo: '2606-0002', branchId: 'b2');

        final result = await repo.searchJobsByJobNo('b1', '2606');
        expect(result.valueOrNull!.map((j) => j.id), ['j1']);

        final empty = await repo.searchJobsByJobNo('b1', '   ');
        expect(empty.valueOrNull, isEmpty);
      });
    });

    group('jobsForCustomers', () {
      test('returns the branch jobs for the given customer ids', () async {
        await seed(id: 'j1', customerId: 'c1');
        await seed(id: 'j2', customerId: 'c2');
        await seed(id: 'j3', customerId: 'c1', branchId: 'b2');

        final result = await repo.jobsForCustomers('b1', ['c1']);

        expect(result.valueOrNull!.map((j) => j.id), ['j1']);
      });

      test('an empty id list yields no results', () async {
        await seed(id: 'j1', customerId: 'c1');
        final result = await repo.jobsForCustomers('b1', const []);
        expect(result.valueOrNull, isEmpty);
      });
    });

    group('jobsForWatches', () {
      test('returns the branch jobs for the given watch ids', () async {
        await seed(id: 'j1', watchId: 'w1');
        await seed(id: 'j2', watchId: 'w2');

        final result = await repo.jobsForWatches('b1', ['w1']);

        expect(result.valueOrNull!.map((j) => j.id), ['j1']);
      });

      test('an empty id list yields no results', () async {
        final result = await repo.jobsForWatches('b1', const []);
        expect(result.valueOrNull, isEmpty);
      });
    });
  });
}
