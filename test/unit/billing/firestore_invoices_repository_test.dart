import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/core/errors/result.dart';
import 'package:service_centre_app/features/billing/data/repositories/firestore_invoice_number_allocator.dart';
import 'package:service_centre_app/features/billing/data/repositories/firestore_invoices_repository.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice_line.dart';
import 'package:service_centre_app/features/billing/domain/repositories/invoice_number_allocator.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

/// An allocator that always fails, to exercise the number-allocation error path.
class _FailingAllocator implements InvoiceNumberAllocator {
  @override
  Future<Result<String>> nextInvoiceNumber(String branchId, {DateTime? now}) =>
      Future.value(const Err(UnexpectedFailure('no number')));
}

void main() {
  group('FirestoreInvoicesRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreInvoicesRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreInvoicesRepository(
        firestore: firestore,
        numberAllocator:
            FirestoreInvoiceNumberAllocator(firestore: firestore),
      );
    });

    const lines = [
      InvoiceLine(desc: 'Service', qty: 2, ratePaise: 50000, gstPct: 18),
      InvoiceLine(desc: 'Battery', qty: 1, ratePaise: 25000, gstPct: 12),
    ];

    Future<String> newInvoice() async {
      final created = await repo.createInvoice(
        jobId: 'j1',
        branchId: 'MAIN',
        lines: lines,
        createdBy: 'u1',
      );
      return created.valueOrNull!.id;
    }

    test('createInvoice computes GST totals and allocates a number', () async {
      final created = await repo.createInvoice(
        jobId: 'j1',
        branchId: 'MAIN',
        lines: lines,
        createdBy: 'u1',
      );

      final invoice = created.valueOrNull!;
      expect(invoice.number, startsWith('INV-'));
      // taxable 100000 + 25000; tax 18000 + 3000; total 146000.
      expect(invoice.taxablePaise, 125000);
      expect(invoice.taxPaise, 21000);
      expect(invoice.totalPaise, 146000);
      expect(invoice.paymentStatus, PaymentStatus.unpaid);
    });

    test('createInvoice logs an activity', () async {
      await newInvoice();
      final log = await firestore.collection('activityLog').get();
      expect(
        log.docs.any((d) => d.data()['action'] == 'invoice.create'),
        isTrue,
      );
    });

    test('watchInvoicesForJob emits the job invoices', () async {
      await newInvoice();
      final list = await repo.watchInvoicesForJob('j1').first;
      expect(list, hasLength(1));
      expect(list.first.jobId, 'j1');
    });

    test('getInvoice returns the invoice, or NotFound when missing', () async {
      final id = await newInvoice();
      expect((await repo.getInvoice(id)).isOk, isTrue);
      expect(
        (await repo.getInvoice('ghost')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('updatePaymentStatus advances the status', () async {
      final id = await newInvoice();

      final result =
          await repo.updatePaymentStatus(id, PaymentStatus.paid, 'u1');

      expect(result.isOk, isTrue);
      expect(
        (await repo.getInvoice(id)).valueOrNull!.paymentStatus,
        PaymentStatus.paid,
      );
    });

    test('updatePaymentStatus on a missing invoice returns NotFound', () async {
      final result =
          await repo.updatePaymentStatus('ghost', PaymentStatus.paid, 'u1');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('invoicesInRange returns only invoices created in the window',
        () async {
      await firestore.collection('invoices').doc('inA').set(<String, dynamic>{
        'jobId': 'j1',
        'branchId': 'MAIN',
        'totalPaise': 100000,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 1, 10)),
      });
      await firestore.collection('invoices').doc('inB').set(<String, dynamic>{
        'jobId': 'j2',
        'branchId': 'MAIN',
        'totalPaise': 50000,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 9, 10)),
      });

      final result = await repo.invoicesInRange(
        'MAIN',
        DateTime.utc(2026, 7, 1),
        DateTime.utc(2026, 7, 2),
      );

      expect(result.valueOrNull!.map((i) => i.id), ['inA']);
    });

    test('propagates a number-allocation failure', () async {
      final failingRepo = FirestoreInvoicesRepository(
        firestore: firestore,
        numberAllocator: _FailingAllocator(),
      );

      final result = await failingRepo.createInvoice(
        jobId: 'j1',
        branchId: 'MAIN',
        lines: lines,
        createdBy: 'u1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test('maps an unexpected write error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      when(() => mock.collection('invoices')).thenThrow(Exception('boom'));
      final mockRepo = FirestoreInvoicesRepository(
        firestore: mock,
        // Allocator uses a separate working fake so it is the write that fails.
        numberAllocator:
            FirestoreInvoiceNumberAllocator(firestore: firestore),
      );

      final result = await mockRepo.createInvoice(
        jobId: 'j1',
        branchId: 'MAIN',
        lines: lines,
        createdBy: 'u1',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
