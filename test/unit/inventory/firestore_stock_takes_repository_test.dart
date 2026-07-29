import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/inventory/data/repositories/firestore_stock_takes_repository.dart';

import '../../support/jobs_harness.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirestoreStockTakesRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreStockTakesRepository repo;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreStockTakesRepository(firestore: firestore);
      await firestore
          .collection('parts')
          .doc('p1')
          .set(partDoc(id: 'p1', reference: 'SR626', onHand: 10));
      await firestore
          .collection('parts')
          .doc('p2')
          .set(partDoc(id: 'p2', reference: 'BATT', onHand: 5));
    });

    test('records variances between counted and system on-hand', () async {
      final result = await repo.recordStockTake(
        branchId: 'b1',
        counts: {'p1': 12, 'p2': 4}, // +2, -1
        by: 'u1',
      );

      final take = result.valueOrNull!;
      expect(take.hasVariance, isTrue);
      expect(take.netVariance, 1);
      final p1 = take.lines.firstWhere((l) => l.partId == 'p1');
      expect(p1.system, 10);
      expect(p1.counted, 12);
      expect(p1.variance, 2);

      // Persisted and streamable.
      final streamed = await repo.watchStockTakes('b1').first;
      expect(streamed, hasLength(1));
    });

    test('treats a missing part as system zero', () async {
      final result = await repo.recordStockTake(
        branchId: 'b1',
        counts: {'ghost': 3},
        by: 'u1',
      );
      final line = result.valueOrNull!.lines.single;
      expect(line.system, 0);
      expect(line.variance, 3);
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      when(() => mock.collection(any())).thenThrow(Exception('boom'));
      final mockRepo = FirestoreStockTakesRepository(firestore: mock);

      final result = await mockRepo.recordStockTake(
        branchId: 'b1',
        counts: {'p1': 1},
        by: 'u1',
      );
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
