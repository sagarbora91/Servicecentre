import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('PartDetailScreen', () {
    testWidgets('shows part fields, pricing, and the low-stock chip',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        parts: [
          partDoc(
            id: 'p1',
            reference: 'SR626',
            category: 'Battery',
            binCode: 'A3',
            onHand: 1,
            reorderPoint: 2,
            costPaise: 1500,
            mrpPaise: 4000,
          ),
        ],
      );

      container.read(routerProvider).go(Routes.partDetail('p1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partDetailScreen')), findsOneWidget);
      expect(find.text('SR626'), findsOneWidget);
      expect(find.text('Battery'), findsOneWidget);
      expect(find.byKey(const Key('partLowStockChip')), findsOneWidget);
      // Cost ₹15.00 and MRP ₹40.00 from paise.
      expect(find.text('₹15.00'), findsOneWidget);
      expect(find.text('₹40.00'), findsOneWidget);
    });

    testWidgets('shows not-found for a missing part', (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.partDetail('ghost'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partNotFound')), findsOneWidget);
    });
  });
}
