import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/customers/data/repositories/firestore_customers_repository.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_jobs_repository.dart';
import 'package:service_centre_app/features/jobs/domain/services/search_jobs_service.dart';

void main() {
  group('SearchJobsService', () {
    late FakeFirebaseFirestore firestore;
    late SearchJobsService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = SearchJobsService(
        jobs: FirestoreJobsRepository(firestore: firestore),
        customers: FirestoreCustomersRepository(firestore),
      );

      Future<void> customer(String id, String name, String phone) =>
          firestore.collection('customers').doc(id).set(<String, dynamic>{
            'name': name,
            'phone': phone,
            'branchId': 'b1',
            'serviceCount': 0,
            'consentWhatsApp': false,
          });
      Future<void> watch(String id, String customerId, String serial) =>
          firestore.collection('watches').doc(id).set(<String, dynamic>{
            'customerId': customerId,
            'brand': 'Titan',
            'model': 'X',
            'photos': <String>[],
            'branchId': 'b1',
            'serial': serial,
          });
      Future<void> job(
        String id,
        String jobNo,
        String customerId, {
        String? watchId,
      }) =>
          firestore.collection('jobs').doc(id).set(<String, dynamic>{
            'jobNo': jobNo,
            'customerId': customerId,
            'branchId': 'b1',
            'status': 'received',
            'dueAt': Timestamp.fromDate(DateTime.utc(2030)),
            if (watchId != null) 'watchId': watchId,
          });

      await customer('c1', 'Asha', '555');
      await customer('c2', 'WX100', '666');
      await watch('w1', 'c1', 'SER123');
      await job('j1', '2606-0001', 'c1');
      await job('j2', '2701-0009', 'c1', watchId: 'w1');
      await job('j3', 'WX100-1', 'c2');
    });

    Future<Set<String>> ids(String query) async =>
        (await service.search('b1', query)).valueOrNull!.map((j) => j.id).toSet();

    test('finds a job by jobNo prefix', () async {
      expect(await ids('2606'), {'j1'});
    });

    test('finds jobs by customer name', () async {
      expect(await ids('Asha'), {'j1', 'j2'});
    });

    test('finds a job by watch serial', () async {
      expect(await ids('SER'), {'j2'});
    });

    test('de-duplicates a job matched on multiple axes', () async {
      // 'WX100' matches j3 both as a jobNo prefix and via its customer name.
      final result = await service.search('b1', 'WX100');
      expect(result.valueOrNull!.map((j) => j.id), ['j3']);
    });

    test('an empty query yields no results', () async {
      expect(await ids('   '), <String>{});
    });
  });
}
