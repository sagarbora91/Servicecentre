import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  testWidgets('dashboard shows received count and revenue for the window',
      (tester) async {
    final now = DateTime.now().toUtc();
    final due = now.add(const Duration(days: 30));

    final container = await pumpBoardApp(
      tester,
      role: UserRole.supervisor,
      customers: [customerDoc(id: 'c1', name: 'Asha')],
      jobs: [
        jobDoc(
          id: 'j1',
          jobNo: '2607-0001',
          customerId: 'c1',
          status: 'received',
          dueAt: due,
          createdAt: now,
        ),
        jobDoc(
          id: 'j2',
          jobNo: '2607-0002',
          customerId: 'c1',
          status: 'in_repair',
          dueAt: due,
          createdAt: now,
        ),
      ],
    );

    // An invoice raised in the window (revenue ₹1180.00).
    await container.read(firestoreProvider).collection('invoices').add({
      'jobId': 'j1',
      'branchId': 'b1',
      'totalPaise': 118000,
      'createdAt': Timestamp.fromDate(now),
    });

    container.read(routerProvider).go(Routes.dashboard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboardScreen')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('kpiReceived'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('kpiRevenue'))).data,
      '₹1180.00',
    );
  });
}
