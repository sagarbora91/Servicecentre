import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);

void main() {
  group('QrLabelScreen', () {
    testWidgets('the detail Label action opens the label with a QR',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
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

      container.read(routerProvider).go(Routes.jobDetail('j1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openLabelBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('qrLabelScreen')), findsOneWidget);
      expect(find.byKey(const Key('jobQr')), findsOneWidget);
      expect(find.text('2606-0001'), findsWidgets);
    });

    testWidgets('the label shows the jobNo, customer, and QR', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
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

      container.read(routerProvider).go(Routes.jobLabel('j1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jobQr')), findsOneWidget);
      expect(find.text('Asha'), findsWidgets);
    });
  });
}
