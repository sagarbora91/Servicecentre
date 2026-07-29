import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _past = DateTime.utc(2026, 6, 1);

void main() {
  testWidgets('captures customer feedback on a delivered job', (tester) async {
    final container = await pumpBoardApp(
      tester,
      role: UserRole.counter,
      customers: [customerDoc(id: 'c1', name: 'Asha')],
      jobs: [
        jobDoc(
          id: 'j1',
          jobNo: '2607-0001',
          customerId: 'c1',
          status: 'delivered',
          dueAt: _past,
        ),
      ],
    );

    container.read(routerProvider).go(Routes.jobDetail('j1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('feedbackBtn')));
    await tester.tap(find.byKey(const Key('feedbackBtn')));
    await tester.pumpAndSettle();

    // Choose 4 stars and submit.
    await tester.tap(find.byKey(const Key('ratingStar_4')));
    await tester.enterText(
      find.byKey(const Key('feedbackCommentField')),
      'Quick and friendly',
    );
    await tester.tap(find.byKey(const Key('feedbackSubmit')));
    await tester.pumpAndSettle();

    final firestore = container.read(firestoreProvider);
    final feedback = await firestore
        .collection('feedback')
        .where('jobId', isEqualTo: 'j1')
        .get();
    expect(feedback.docs, hasLength(1));
    expect(feedback.docs.first.data()['rating'], 4);
    expect(feedback.docs.first.data()['comment'], 'Quick and friendly');
  });
}
