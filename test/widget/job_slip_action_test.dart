import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  testWidgets('job detail shows the print-slip action', (tester) async {
    final container = await pumpBoardApp(
      tester,
      customers: [customerDoc(id: 'c1', name: 'Asha')],
      jobs: [
        jobDoc(
          id: 'j1',
          jobNo: '2606-0001',
          customerId: 'c1',
          status: 'received',
          dueAt: DateTime.utc(2999),
        ),
      ],
    );

    container.read(routerProvider).go(Routes.jobDetail('j1'));
    await tester.pumpAndSettle();

    // The action is present; tapping it opens the native print dialog
    // (device-QA), so the flow itself is not driven here.
    expect(find.byKey(const Key('printSlipBtn')), findsOneWidget);
  });
}
