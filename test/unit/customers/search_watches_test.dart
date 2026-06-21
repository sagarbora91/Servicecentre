import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/customers/data/repositories/firestore_customers_repository.dart';

void main() {
  group('FirestoreCustomersRepository.searchWatchesBySerial', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreCustomersRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreCustomersRepository(firestore);
    });

    Future<void> seedWatch({
      required String id,
      required String serial,
      String branchId = 'b1',
    }) =>
        firestore.collection('watches').doc(id).set(<String, dynamic>{
          'customerId': 'c1',
          'brand': 'Titan',
          'model': 'X',
          'photos': <String>[],
          'branchId': branchId,
          'serial': serial,
        });

    test('matches a serial prefix within the branch', () async {
      await seedWatch(id: 'w1', serial: 'SER123');
      await seedWatch(id: 'w2', serial: 'SER999');
      await seedWatch(id: 'w3', serial: 'OTHER');
      await seedWatch(id: 'w4', serial: 'SER000', branchId: 'b2');

      final result = await repo.searchWatchesBySerial('b1', 'SER');

      expect(result.valueOrNull!.map((w) => w.id).toSet(), {'w1', 'w2'});
    });

    test('an empty query yields no results', () async {
      await seedWatch(id: 'w1', serial: 'SER123');
      final result = await repo.searchWatchesBySerial('b1', '  ');
      expect(result.valueOrNull, isEmpty);
    });
  });
}
