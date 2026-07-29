import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';
import 'package:service_centre_app/features/data_import/presentation/controllers/import_controller.dart';

import '../support/jobs_harness.dart';

void main() {
  group('ImportScreen', () {
    testWidgets('owner previews a CSV and imports the valid rows',
        (tester) async {
      final container = await pumpBoardApp(tester, role: UserRole.owner);

      container.read(routerProvider).go(Routes.dataImport);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('importScreen')), findsOneWidget);

      // Drive the preview directly (the native file picker is device-QA).
      container
          .read(importControllerProvider.notifier)
          .previewCustomers('name,phone\nAsha,111\nBhau,222\n');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('importPreview')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('importBtn')));
      await tester.tap(find.byKey(const Key('importBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('importOutcome')), findsOneWidget);
      final customers =
          await container.read(firestoreProvider).collection('customers').get();
      expect(customers.docs, hasLength(2));
    });

    testWidgets('a non-owner is bounced from the import route', (tester) async {
      final container = await pumpBoardApp(tester, role: UserRole.supervisor);

      container.read(routerProvider).go(Routes.dataImport);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('importScreen')), findsNothing);
    });
  });
}
