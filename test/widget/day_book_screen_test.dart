import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('Day-book screen', () {
    testWidgets('reconciles the day collections by mode', (tester) async {
      final container = await pumpBoardApp(tester, role: UserRole.supervisor);

      // Seed two payments dated today (UTC noon, within the default day window).
      final now = DateTime.now().toUtc();
      final at = Timestamp.fromDate(DateTime.utc(now.year, now.month, now.day, 12));
      final firestore = container.read(firestoreProvider);
      await firestore.collection('payments').add(<String, dynamic>{
        'invoiceId': 'inv1',
        'branchId': 'b1',
        'amountPaise': 50000,
        'mode': 'cash',
        'at': at,
      });
      await firestore.collection('payments').add(<String, dynamic>{
        'invoiceId': 'inv2',
        'branchId': 'b1',
        'amountPaise': 120000,
        'mode': 'upi',
        'at': at,
      });

      container.read(routerProvider).go(Routes.dayBook);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dayBookScreen')), findsOneWidget);
      // Grand total = ₹500 + ₹1200 = ₹1700.00.
      expect(find.byKey(const Key('dayBookTotal')), findsOneWidget);
      expect(find.text('₹1700.00'), findsOneWidget);
      // Per-mode rows.
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('₹1200.00'), findsOneWidget);
      // Export is enabled when there are payments.
      expect(find.byKey(const Key('dayBookExportBtn')), findsOneWidget);
    });

    testWidgets('shows zeros for a day with no payments', (tester) async {
      final container = await pumpBoardApp(tester, role: UserRole.owner);

      container.read(routerProvider).go(Routes.dayBook);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dayBookTotal')), findsOneWidget);
      // Cash/UPI/Card/Total all ₹0.00.
      expect(find.text('₹0.00'), findsWidgets);
    });
  });
}
