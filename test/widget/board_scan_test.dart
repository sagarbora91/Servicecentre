import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  testWidgets('the board shows the scan-to-open action', (tester) async {
    final container = await pumpBoardApp(tester);

    container.read(routerProvider).go(Routes.board);
    await tester.pumpAndSettle();

    // Present and routed; tapping opens the camera scanner (device-QA), so the
    // scan screen itself is not pumped here.
    expect(find.byKey(const Key('boardScanBtn')), findsOneWidget);
  });
}
