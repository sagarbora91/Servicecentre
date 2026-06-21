import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/jobs/data/repositories/firestore_job_no_allocator.dart';

class _ThrowingFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw StateError('boom');
}

void main() {
  group('FirestoreJobNoAllocator', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreJobNoAllocator allocator;
    final june = DateTime.utc(2026, 6, 15);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      allocator = FirestoreJobNoAllocator(firestore: firestore);
    });

    test('allocates a sequential YYMM-NNNN per branch and month', () async {
      final first = await allocator.nextJobNo('MAIN', now: june);
      final second = await allocator.nextJobNo('MAIN', now: june);

      expect(first.valueOrNull, '2606-0001');
      expect(second.valueOrNull, '2606-0002');
    });

    test('counts independently per branch', () async {
      await allocator.nextJobNo('MAIN', now: june);
      final other = await allocator.nextJobNo('CITY', now: june);

      expect(other.valueOrNull, '2606-0001');
    });

    test('resets the sequence each month', () async {
      await allocator.nextJobNo('MAIN', now: june);
      final july = await allocator.nextJobNo(
        'MAIN',
        now: DateTime.utc(2026, 7, 1),
      );

      expect(july.valueOrNull, '2607-0001');
    });

    test('persists the counter so a fresh allocator continues the run',
        () async {
      await allocator.nextJobNo('MAIN', now: june);
      final fresh = FirestoreJobNoAllocator(firestore: firestore);

      final next = await fresh.nextJobNo('MAIN', now: june);

      expect(next.valueOrNull, '2606-0002');
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing =
          FirestoreJobNoAllocator(firestore: _ThrowingFirestore());

      final result = await throwing.nextJobNo('MAIN', now: june);

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
