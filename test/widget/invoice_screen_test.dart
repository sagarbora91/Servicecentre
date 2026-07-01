import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);

List<Map<String, dynamic>> _jobs() => [
      jobDoc(
        id: 'j1',
        jobNo: '2607-0001',
        customerId: 'c1',
        status: 'ready',
        dueAt: _future,
      ),
    ];

void main() {
  group('Invoice screen', () {
    testWidgets('finance builds a line and creates an invoice', (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.supervisor,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      container.read(routerProvider).go(Routes.jobInvoice('j1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invoiceEmpty')), findsOneWidget);
      expect(find.byKey(const Key('invoiceBuilder')), findsOneWidget);

      // Add one line: ₹2500.00 @ 0% (bill of supply).
      await tester.tap(find.byKey(const Key('invoiceAddLineBtn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invoiceLineDescField')),
        'Movement service',
      );
      await tester.enterText(
        find.byKey(const Key('invoiceLineRateField')),
        '2500',
      );
      await tester.tap(find.byKey(const Key('invoiceLineConfirm')));
      await tester.pumpAndSettle();

      // Create the invoice.
      await tester.tap(find.byKey(const Key('invoiceCreateBtn')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final invoices = await firestore
          .collection('invoices')
          .where('jobId', isEqualTo: 'j1')
          .get();
      expect(invoices.docs, hasLength(1));
      final data = invoices.docs.first.data();
      expect(data['totalPaise'], 250000);
      expect(data['taxPaise'], 0);
      expect(data['paymentStatus'], 'unpaid');
      expect((data['number'] as String).startsWith('INV-'), isTrue);
    });

    testWidgets('a tax line splits into CGST/SGST in the stored totals',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.owner,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      container.read(routerProvider).go(Routes.jobInvoice('j1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invoiceAddLineBtn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invoiceLineDescField')),
        'Service',
      );
      await tester.enterText(
        find.byKey(const Key('invoiceLineRateField')),
        '1000',
      );
      await tester.enterText(
        find.byKey(const Key('invoiceLineGstField')),
        '18',
      );
      await tester.tap(find.byKey(const Key('invoiceLineConfirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invoiceCreateBtn')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final invoices = await firestore
          .collection('invoices')
          .where('jobId', isEqualTo: 'j1')
          .get();
      final data = invoices.docs.first.data();
      // ₹1000 @ 18% -> taxable 100000, tax 18000, total 118000.
      expect(data['taxablePaise'], 100000);
      expect(data['taxPaise'], 18000);
      expect(data['totalPaise'], 118000);
    });

    testWidgets('finance records a payment that clears the balance',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.supervisor,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      // Seed an unpaid invoice for the job.
      final firestore = container.read(firestoreProvider);
      await firestore.collection('invoices').doc('inv1').set(<String, dynamic>{
        'jobId': 'j1',
        'number': 'INV-2607-0009',
        'branchId': 'b1',
        'lines': <dynamic>[],
        'taxablePaise': 100000,
        'taxPaise': 0,
        'totalPaise': 100000,
        'amountPaidPaise': 0,
        'paymentStatus': 'unpaid',
        'place': 'intra_state',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7)),
      });

      container.read(routerProvider).go(Routes.jobInvoice('j1'));
      await tester.pumpAndSettle();

      // Record a full payment (amount pre-filled to the balance).
      await tester.tap(find.byKey(const Key('invoicePayBtn_inv1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('paymentConfirm')));
      await tester.pumpAndSettle();

      final inv =
          (await firestore.collection('invoices').doc('inv1').get()).data()!;
      expect(inv['amountPaidPaise'], 100000);
      expect(inv['paymentStatus'], 'paid');
      final payments = await firestore.collection('payments').get();
      expect(payments.docs, hasLength(1));
    });

    testWidgets('a technician sees no invoice builder', (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.technician,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      container.read(routerProvider).go(Routes.jobInvoice('j1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invoiceScreen')), findsOneWidget);
      expect(find.byKey(const Key('invoiceBuilder')), findsNothing);
    });
  });
}
