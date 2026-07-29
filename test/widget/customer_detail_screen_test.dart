import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);

void main() {
  group('CustomerDetailScreen', () {
    testWidgets('shows profile, watches, and service history', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha', phone: '111')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'received',
            dueAt: _future,
          ),
        ],
      );

      // Seed a watch for the customer (the harness seeds customers + jobs only).
      await container.read(firestoreProvider).collection('watches').doc('w1').set(
        <String, dynamic>{
          'customerId': 'c1',
          'brand': 'Titan',
          'model': 'Edge',
          'photos': <String>[],
          'branchId': 'b1',
          'serial': 'SER1',
        },
      );

      container.read(routerProvider).go(Routes.customerDetail('c1'));
      await tester.pumpAndSettle();

      expect(find.text('Asha'), findsWidgets);
      expect(find.byKey(const Key('watchTile_w1')), findsOneWidget);
      expect(find.byKey(const Key('historyTile_j1')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('historyTile_j1')));
      await tester.tap(find.byKey(const Key('historyTile_j1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('jobDetailScreen')), findsOneWidget);
    });

    testWidgets('shows not-found for a missing customer', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
      );

      container.read(routerProvider).go(Routes.customerDetail('ghost'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customerNotFound')), findsOneWidget);
    });
  });
}
