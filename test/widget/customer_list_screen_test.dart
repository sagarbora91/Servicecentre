import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('CustomerListScreen', () {
    testWidgets('lists customers and filters by query', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [
          customerDoc(id: 'c1', name: 'Asha', phone: '111'),
          customerDoc(id: 'c2', name: 'Bhau', phone: '222'),
        ],
      );

      container.read(routerProvider).go(Routes.customers);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customerTile_c1')), findsOneWidget);
      expect(find.byKey(const Key('customerTile_c2')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('customerSearchField')),
        'Asha',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customerTile_c1')), findsOneWidget);
      expect(find.byKey(const Key('customerTile_c2')), findsNothing);

      await tester.tap(find.byKey(const Key('customerTile_c1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customerDetailScreen')), findsOneWidget);
    });

    testWidgets('shows the empty state with no customers', (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.customers);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customersEmpty')), findsOneWidget);
    });

    testWidgets('shows the no-branch state when the profile has no branch',
        (tester) async {
      final container = await pumpBoardApp(tester, branchId: null);

      container.read(routerProvider).go(Routes.customers);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customersNoBranch')), findsOneWidget);
    });
  });
}
