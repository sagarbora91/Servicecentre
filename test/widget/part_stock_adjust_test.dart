import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

Future<int> _onHand(ProviderContainer container, String id) async {
  final snap =
      await container.read(firestoreProvider).collection('parts').doc(id).get();
  return (snap.data()!['onHand'] as num).toInt();
}

void main() {
  group('Part stock adjust', () {
    testWidgets('store receives stock — on-hand increments transactionally',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.store,
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.partDetail('p1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('receiveStockBtn')));
      await tester.tap(find.byKey(const Key('receiveStockBtn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('stockQtyField')), '3');
      await tester.tap(find.byKey(const Key('stockDialogConfirm')));
      await tester.pumpAndSettle();

      expect(await _onHand(container, 'p1'), 8);
      expect(find.text('Stock received'), findsOneWidget);
    });

    testWidgets('an adjust below zero is rejected; on-hand is unchanged',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.store,
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.partDetail('p1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('adjustStockBtn')));
      await tester.tap(find.byKey(const Key('adjustStockBtn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('stockQtyField')), '-10');
      await tester.tap(find.byKey(const Key('stockDialogConfirm')));
      await tester.pumpAndSettle();

      expect(find.text('Not enough stock for that change.'), findsOneWidget);
      expect(await _onHand(container, 'p1'), 5);
    });

    testWidgets('a negative adjust within stock decrements on-hand',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.store,
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.partDetail('p1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('adjustStockBtn')));
      await tester.tap(find.byKey(const Key('adjustStockBtn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('stockQtyField')), '-2');
      await tester.tap(find.byKey(const Key('stockDialogConfirm')));
      await tester.pumpAndSettle();

      expect(await _onHand(container, 'p1'), 3);
      expect(find.text('Stock adjusted'), findsOneWidget);
    });

    testWidgets('a non-inventory role does not see the stock actions',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.counter,
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.partDetail('p1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partDetailScreen')), findsOneWidget);
      expect(find.byKey(const Key('receiveStockBtn')), findsNothing);
      expect(find.byKey(const Key('adjustStockBtn')), findsNothing);
    });
  });
}
