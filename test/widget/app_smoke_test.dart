import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/auth_harness.dart';

void main() {
  testWidgets('a signed-out boot lands on the login screen', (tester) async {
    await pumpAppSignedOut(tester);

    // The sign-in button is the stable, language-agnostic anchor for the
    // login screen.
    expect(find.byKey(const Key('signInBtn')), findsOneWidget);
  });
}
