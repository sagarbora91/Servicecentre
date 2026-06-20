import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/auth_harness.dart';

void main() {
  group('role-based routing', () {
    testWidgets('owner home shows billing and admin entries', (tester) async {
      await pumpAppSignedIn(tester, role: UserRole.owner);

      expect(find.byKey(const Key('roleChip')), findsOneWidget);
      expect(find.byKey(const Key('openBillingBtn')), findsOneWidget);
      expect(find.byKey(const Key('openAdminBtn')), findsOneWidget);
    });

    testWidgets('technician home shows neither entry', (tester) async {
      await pumpAppSignedIn(tester, role: UserRole.technician);

      expect(find.byKey(const Key('roleChip')), findsOneWidget);
      expect(find.byKey(const Key('openBillingBtn')), findsNothing);
      expect(find.byKey(const Key('openAdminBtn')), findsNothing);
    });

    testWidgets('supervisor can reach the billing route', (tester) async {
      final container =
          await pumpAppSignedIn(tester, role: UserRole.supervisor);

      container.read(routerProvider).go(Routes.billing);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('billingScreen')), findsOneWidget);
    });

    testWidgets('counter is bounced from the billing route', (tester) async {
      final container = await pumpAppSignedIn(tester, role: UserRole.counter);

      container.read(routerProvider).go(Routes.billing);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('billingScreen')), findsNothing);
      expect(find.byKey(const Key('roleChip')), findsOneWidget);
    });

    testWidgets('only the owner can reach admin users', (tester) async {
      final container =
          await pumpAppSignedIn(tester, role: UserRole.supervisor);

      container.read(routerProvider).go(Routes.adminUsers);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adminUsersScreen')), findsNothing);
      expect(find.byKey(const Key('roleChip')), findsOneWidget);
    });

    testWidgets('signed-in user without a profile sees the no-role message',
        (tester) async {
      await pumpAppSignedIn(tester, role: null);

      expect(find.byKey(const Key('noRoleMessage')), findsOneWidget);
    });

    testWidgets('deactivated user sees the deactivated message',
        (tester) async {
      await pumpAppSignedIn(
        tester,
        role: UserRole.counter,
        active: false,
      );

      expect(find.byKey(const Key('deactivatedMessage')), findsOneWidget);
    });
  });
}
