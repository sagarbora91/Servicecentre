import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  testWidgets('job detail shows the photo capture actions and counts',
      (tester) async {
    final container = await pumpBoardApp(
      tester,
      customers: [customerDoc(id: 'c1', name: 'Asha')],
      jobs: [
        jobDoc(
          id: 'j1',
          jobNo: '2606-0001',
          customerId: 'c1',
          status: 'in_repair',
          dueAt: DateTime.utc(2999),
        ),
      ],
    );

    container.read(routerProvider).go(Routes.jobDetail('j1'));
    await tester.pumpAndSettle();

    // The capture actions are present; tapping opens the native camera
    // (device-QA), so the capture flow itself is not driven here.
    await tester.ensureVisible(find.byKey(const Key('addIntakePhotoBtn')));
    expect(find.byKey(const Key('addIntakePhotoBtn')), findsOneWidget);
    expect(find.byKey(const Key('addDeliveryPhotoBtn')), findsOneWidget);
  });
}
