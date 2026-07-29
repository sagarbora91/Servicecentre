import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('IntakeScreen', () {
    testWidgets('the board FAB opens intake', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
      );

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('newJobFab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('intakeScreen')), findsOneWidget);
    });

    testWidgets('shows the no-customers state when the branch has none',
        (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.jobIntake);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('intakeNoCustomers')), findsOneWidget);
    });

    testWidgets('validates required fields', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
      );

      container.read(routerProvider).go(Routes.jobIntake);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveJobBtn')));
      await tester.pumpAndSettle();

      expect(find.text('Select a customer'), findsOneWidget);
      expect(find.text('Describe the fault'), findsOneWidget);
      expect(find.text('Describe the work requested'), findsOneWidget);
    });

    testWidgets('creates a job that lands on the board', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
      );

      container.read(routerProvider).go(Routes.jobIntake);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('customerDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('faultField')),
        'Not ticking',
      );
      await tester.enterText(find.byKey(const Key('workField')), 'Service');
      await tester.tap(find.byKey(const Key('saveJobBtn')));
      await tester.pumpAndSettle();

      // Navigated to the board after creating.
      expect(find.byKey(const Key('boardScreen')), findsOneWidget);

      final firestore = container.read(firestoreProvider);
      final jobs = await firestore.collection('jobs').get();
      expect(jobs.docs, hasLength(1));
      final job = jobs.docs.first.data();
      expect(job['status'], 'received');
      expect(job['customerId'], 'c1');
      expect(job['jobNo'], matches(r'^\d{4}-\d{4}$'));
    });
  });
}
