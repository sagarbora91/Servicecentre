import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/billing/data/repositories/firestore_invoice_number_allocator.dart';

class _ThrowingFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw StateError('boom');
}

void main() {
  group('FirestoreInvoiceNumberAllocator', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreInvoiceNumberAllocator allocator;
    final july = DateTime.utc(2026, 7, 15);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      allocator = FirestoreInvoiceNumberAllocator(firestore: firestore);
    });

    test('allocates a sequential INV-YYMM-NNNN per branch and month', () async {
      final first = await allocator.nextInvoiceNumber('MAIN', now: july);
      final second = await allocator.nextInvoiceNumber('MAIN', now: july);

      expect(first.valueOrNull, 'INV-2607-0001');
      expect(second.valueOrNull, 'INV-2607-0002');
    });

    test('uses a counter separate from the jobNo sequence', () async {
      await allocator.nextInvoiceNumber('MAIN', now: july);

      // The invoice counter lives at a distinct doc id so it never collides
      // with the jobNo counter (`MAIN_2607`).
      final jobCounter =
          await firestore.collection('counters').doc('MAIN_2607').get();
      final invCounter =
          await firestore.collection('counters').doc('MAIN_INV_2607').get();
      expect(jobCounter.exists, isFalse);
      expect(invCounter.exists, isTrue);
    });

    test('resets each month', () async {
      await allocator.nextInvoiceNumber('MAIN', now: july);
      final august = await allocator.nextInvoiceNumber(
        'MAIN',
        now: DateTime.utc(2026, 8, 1),
      );

      expect(august.valueOrNull, 'INV-2608-0001');
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing =
          FirestoreInvoiceNumberAllocator(firestore: _ThrowingFirestore());

      final result = await throwing.nextInvoiceNumber('MAIN', now: july);

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
