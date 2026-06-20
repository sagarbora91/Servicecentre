import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/app.dart';

void main() {
  testWidgets('app boots to the placeholder home', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ServiceCentreApp()),
    );
    await tester.pumpAndSettle();

    // The placeholder home renders (identified by a stable key, not a
    // localized string, so the test is language-agnostic).
    expect(find.byKey(const Key('homePlaceholderIcon')), findsOneWidget);
  });
}
