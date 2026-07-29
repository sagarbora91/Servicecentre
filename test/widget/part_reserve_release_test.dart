import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

Future<int> _reserved(ProviderContainer container) async {
  final doc = await container
      .read(firestoreProvider)
      .collection('parts')
      .doc('p1')
      .get();
  return (doc.data()!['reserved'] as num).toInt();
}

void main() {
  testWidgets('inventory keeper reserves then releases stock', (tester) async {
    final container = await pumpBoardApp(
      tester,
      role: UserRole.store,
      parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 10)],
    );
    container.read(routerProvider).go(Routes.partDetail('p1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('reserveStockBtn')));
    await tester.tap(find.byKey(const Key('reserveStockBtn')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('stockQtyField')), '4');
    await tester.tap(find.byKey(const Key('stockDialogConfirm')));
    await tester.pumpAndSettle();
    expect(await _reserved(container), 4);
    expect(find.text('Stock reserved.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('releaseStockBtn')));
    await tester.tap(find.byKey(const Key('releaseStockBtn')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('stockQtyField')), '1');
    await tester.tap(find.byKey(const Key('stockDialogConfirm')));
    await tester.pumpAndSettle();
    expect(await _reserved(container), 3);
    expect(find.text('Stock released.'), findsOneWidget);
  });

  testWidgets('counter cannot see reserve or release controls', (tester) async {
    final container = await pumpBoardApp(
      tester,
      role: UserRole.counter,
      parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 10)],
    );
    container.read(routerProvider).go(Routes.partDetail('p1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reserveStockBtn')), findsNothing);
    expect(find.byKey(const Key('releaseStockBtn')), findsNothing);
  });
}
