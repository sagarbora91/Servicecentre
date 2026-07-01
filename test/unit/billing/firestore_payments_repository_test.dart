import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/billing/data/repositories/firestore_payments_repository.dart';
import 'package:service_centre_app/features/billing/domain/entities/payment_mode.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirestorePaymentsRepository.recordPayment', () {
    late FakeFirebaseFirestore firestore;
    late FirestorePaymentsRepository repo;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repo = FirestorePaymentsRepository(firestore: firestore);
      await firestore.collection('invoices').doc('inv1').set(<String, dynamic>{
        'jobId': 'j1',
        'number': 'INV-2607-0001',
        'branchId': 'MAIN',
        'totalPaise': 100000,
        'amountPaidPaise': 0,
        'paymentStatus': 'unpaid',
      });
    });

    Future<Map<String, dynamic>> invoice() async =>
        (await firestore.collection('invoices').doc('inv1').get()).data()!;

    test('a partial payment advances the paid total and status', () async {
      final result = await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 40000,
        mode: PaymentMode.upi,
        by: 'u1',
      );

      expect(result.isOk, isTrue);
      final inv = await invoice();
      expect(inv['amountPaidPaise'], 40000);
      expect(inv['paymentStatus'], 'partial');
    });

    test('successive payments reach paid and never over-collect', () async {
      await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 60000,
        mode: PaymentMode.cash,
        by: 'u1',
      );
      final second = await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 40000,
        mode: PaymentMode.card,
        by: 'u1',
      );

      expect(second.isOk, isTrue);
      final inv = await invoice();
      expect(inv['amountPaidPaise'], 100000);
      expect(inv['paymentStatus'], 'paid');

      // A further payment would over-collect -> rejected, nothing written.
      final third = await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 1,
        mode: PaymentMode.cash,
        by: 'u1',
      );
      final failure = third.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).reason,
        ValidationReason.paymentExceedsBalance,
      );
      expect((await invoice())['amountPaidPaise'], 100000);
    });

    test('rejects a payment larger than the balance, writing nothing',
        () async {
      final result = await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 150000,
        mode: PaymentMode.cash,
        by: 'u1',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      final inv = await invoice();
      expect(inv['amountPaidPaise'], 0);
      expect(inv['paymentStatus'], 'unpaid');
      final payments = await firestore.collection('payments').get();
      expect(payments.docs, isEmpty);
    });

    test('rejects a non-positive amount', () async {
      final result = await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 0,
        mode: PaymentMode.cash,
        by: 'u1',
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('a missing invoice returns NotFoundFailure', () async {
      final result = await repo.recordPayment(
        invoiceId: 'ghost',
        branchId: 'MAIN',
        amountPaise: 100,
        mode: PaymentMode.cash,
        by: 'u1',
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('records the payment and logs an activity', () async {
      await repo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 25000,
        mode: PaymentMode.upi,
        by: 'u1',
        ref: 'UPI123',
      );

      final payments = await repo.watchPaymentsForInvoice('inv1').first;
      expect(payments, hasLength(1));
      expect(payments.first.amountPaise, 25000);
      expect(payments.first.mode, PaymentMode.upi);
      expect(payments.first.ref, 'UPI123');

      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'payment.record.upi'),
        isTrue,
      );
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      when(() => mock.collection('payments')).thenThrow(Exception('boom'));
      final mockRepo = FirestorePaymentsRepository(firestore: mock);

      final result = await mockRepo.recordPayment(
        invoiceId: 'inv1',
        branchId: 'MAIN',
        amountPaise: 100,
        mode: PaymentMode.cash,
        by: 'u1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
