import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  group('CustomerFormScreen', () {
    testWidgets('the FAB opens the form and validates', (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.customers);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCustomerFab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customerFormScreen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('saveCustomerBtn')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter a phone number'), findsOneWidget);
    });

    testWidgets('creates a customer and returns to the list', (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.customers);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCustomerFab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'Asha',
      );
      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '555',
      );
      await tester.tap(find.byKey(const Key('saveCustomerBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customerListScreen')), findsOneWidget);
      final customers =
          await container.read(firestoreProvider).collection('customers').get();
      expect(customers.docs, hasLength(1));
      expect(customers.docs.first.data()['name'], 'Asha');
    });

    testWidgets('shows the de-dupe error for a duplicate phone',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Existing', phone: '555')],
      );

      container.read(routerProvider).go(Routes.customers);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCustomerFab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('customerNameField')), 'New');
      await tester.enterText(
        find.byKey(const Key('customerPhoneField')),
        '555',
      );
      await tester.tap(find.byKey(const Key('saveCustomerBtn')));
      await tester.pumpAndSettle();

      // Stays on the form and surfaces the conflict.
      expect(find.byKey(const Key('customerFormScreen')), findsOneWidget);
      expect(
        find.text('A customer with this phone already exists.'),
        findsOneWidget,
      );
    });

    testWidgets('edits an existing customer', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha', phone: '555')],
      );

      container.read(routerProvider).go(Routes.customerDetail('c1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('editCustomerBtn')));
      await tester.tap(find.byKey(const Key('editCustomerBtn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('customerNameField')),
        'Asha R',
      );
      await tester.tap(find.byKey(const Key('saveCustomerBtn')));
      await tester.pumpAndSettle();

      final customer = (await container
              .read(firestoreProvider)
              .collection('customers')
              .doc('c1')
              .get())
          .data()!;
      expect(customer['name'], 'Asha R');
    });
  });
}
