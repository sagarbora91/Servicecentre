import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

void main() {
  testWidgets('owner sees recent activity entries', (tester) async {
    final container = await pumpBoardApp(tester, role: UserRole.owner);

    await container.read(firestoreProvider).collection('activityLog').add({
      'actor': 'owner-uid',
      'action': 'job.deliver',
      'entity': 'jobs',
      'entityId': 'j1',
      'at': Timestamp.fromDate(DateTime.utc(2026, 7, 1, 12)),
    });

    container.read(routerProvider).go(Routes.auditLog);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auditLogScreen')), findsOneWidget);
    expect(find.text('job.deliver'), findsOneWidget);
  });
}
