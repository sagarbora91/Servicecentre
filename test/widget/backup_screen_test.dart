import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  testWidgets('owner can open the branch backup screen', (tester) async {
    final container = await pumpBoardApp(tester, role: UserRole.owner);

    container.read(routerProvider).go(Routes.backup);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backupScreen')), findsOneWidget);
    expect(find.byKey(const Key('createBackupBtn')), findsOneWidget);
  });

  testWidgets('non-owner is redirected away from the backup screen',
      (tester) async {
    final container = await pumpBoardApp(tester, role: UserRole.supervisor);

    container.read(routerProvider).go(Routes.backup);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backupScreen')), findsNothing);
  });
}
