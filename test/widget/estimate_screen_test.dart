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
        jobNo: '2606-0001',
        customerId: 'c1',
        status: 'in_repair',
        dueAt: _future,
      ),
    ];

void main() {
  group('Estimate screen', () {
    testWidgets('counter creates a draft estimate and approves it',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.counter,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      container.read(routerProvider).go(Routes.jobEstimate('j1'));
      await tester.pumpAndSettle();

      // Empty state, with the create FAB for a quoting role.
      expect(find.byKey(const Key('estimateEmpty')), findsOneWidget);
      expect(find.byKey(const Key('newEstimateBtn')), findsOneWidget);

      // Create a draft with one line.
      await tester.tap(find.byKey(const Key('newEstimateBtn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('estimateLineDescField')),
        'Full service',
      );
      await tester.enterText(
        find.byKey(const Key('estimateLineAmountField')),
        '2500',
      );
      await tester.tap(find.byKey(const Key('estimateLineConfirm')));
      await tester.pumpAndSettle();

      // The estimate is shown with its total (₹2500.00) and a Draft status.
      expect(find.byKey(const Key('estimateTotal')), findsOneWidget);
      expect(find.text('₹2500.00'), findsWidgets);

      final firestore = container.read(firestoreProvider);
      final created = await firestore
          .collection('estimates')
          .where('jobId', isEqualTo: 'j1')
          .get();
      expect(created.docs, hasLength(1));
      expect(created.docs.first.data()['status'], 'draft');
      expect(created.docs.first.data()['totalPaise'], 250000);

      // Approve it.
      await tester.tap(find.byKey(const Key('estimateApproveBtn')));
      await tester.pumpAndSettle();

      final after = await firestore
          .collection('estimates')
          .where('jobId', isEqualTo: 'j1')
          .get();
      expect(after.docs.first.data()['status'], 'approved');
    });

    testWidgets('technician cannot create estimates (no create button)',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.technician,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      container.read(routerProvider).go(Routes.jobEstimate('j1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('estimateScreen')), findsOneWidget);
      expect(find.byKey(const Key('newEstimateBtn')), findsNothing);
    });

    testWidgets('shows a seeded estimate and its total', (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.supervisor,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
      );

      await container.read(firestoreProvider).collection('estimates').add({
        'jobId': 'j1',
        'branchId': 'b1',
        'lines': [
          {'desc': 'Movement service', 'amountPaise': 180000},
          {'desc': 'Battery', 'amountPaise': 25000},
        ],
        'totalPaise': 205000,
        'status': 'sent',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6)),
      });

      container.read(routerProvider).go(Routes.jobEstimate('j1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('estimateTotal')), findsOneWidget);
      expect(find.text('₹2050.00'), findsOneWidget);
    });
  });
}
