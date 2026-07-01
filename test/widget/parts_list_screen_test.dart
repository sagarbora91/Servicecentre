import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('PartsListScreen', () {
    testWidgets('lists parts, marks low stock, and filters', (tester) async {
      final container = await pumpBoardApp(
        tester,
        parts: [
          partDoc(
            id: 'p1',
            reference: 'SR626',
            category: 'Battery',
            onHand: 0,
            reorderPoint: 2,
          ),
          partDoc(
            id: 'p2',
            reference: 'AAA22',
            category: 'Strap',
            onHand: 10,
            reorderPoint: 2,
          ),
        ],
      );

      container.read(routerProvider).go(Routes.parts);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partTile_p1')), findsOneWidget);
      expect(find.byKey(const Key('partTile_p2')), findsOneWidget);
      // p1 is at/under its reorder point → low-stock marker; p2 is not.
      expect(find.byKey(const Key('lowStock_p1')), findsOneWidget);
      expect(find.byKey(const Key('lowStock_p2')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('partsSearchField')),
        'Strap',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partTile_p1')), findsNothing);
      expect(find.byKey(const Key('partTile_p2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('partTile_p2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('partDetailScreen')), findsOneWidget);
    });

    testWidgets('shows the empty state with no parts', (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.parts);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partsEmpty')), findsOneWidget);
    });

    testWidgets('shows the no-branch state when the profile has no branch',
        (tester) async {
      final container = await pumpBoardApp(tester, branchId: null);

      container.read(routerProvider).go(Routes.parts);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partsNoBranch')), findsOneWidget);
    });
  });
}
