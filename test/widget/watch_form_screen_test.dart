import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('WatchFormScreen', () {
    testWidgets('adds a watch to a customer from detail', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
      );

      container.read(routerProvider).go(Routes.customerDetail('c1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('addWatchBtn')));
      await tester.tap(find.byKey(const Key('addWatchBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('watchFormScreen')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('watchBrandField')), 'Titan');
      await tester.enterText(find.byKey(const Key('watchModelField')), 'Edge');
      await tester.tap(find.byKey(const Key('saveWatchBtn')));
      await tester.pumpAndSettle();

      final watches =
          await container.read(firestoreProvider).collection('watches').get();
      expect(watches.docs, hasLength(1));
      final watch = watches.docs.first.data();
      expect(watch['customerId'], 'c1');
      expect(watch['brand'], 'Titan');
      expect(watch['model'], 'Edge');
    });

    testWidgets('validates required brand and model', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
      );

      container.read(routerProvider).go(Routes.customerDetail('c1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('addWatchBtn')));
      await tester.tap(find.byKey(const Key('addWatchBtn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveWatchBtn')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the brand'), findsOneWidget);
      expect(find.text('Enter the model'), findsOneWidget);
    });
  });
}
