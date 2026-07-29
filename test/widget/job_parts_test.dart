import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);

List<Map<String, dynamic>> _jobs() => [
      jobDoc(
        id: 'j1',
        jobNo: '2606-0001',
        customerId: 'c1',
        status: 'in_repair',
        dueAt: _future,
      ),
    ];

void main() {
  group('Parts on a job', () {
    testWidgets('store logs a part: stock decrements and the job reflects it',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.store,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.jobDetail('j1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('addPartBtn')));
      await tester.tap(find.byKey(const Key('addPartBtn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('partDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SR626 (5)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('partQtyField')), '2');
      await tester.tap(find.byKey(const Key('addPartConfirm')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final part =
          (await firestore.collection('parts').doc('p1').get()).data()!;
      expect(part['onHand'], 3);

      final job = (await firestore.collection('jobs').doc('j1').get()).data()!;
      final partsUsed = job['partsUsed'] as List;
      expect(partsUsed, hasLength(1));
      expect((partsUsed.first as Map)['partId'], 'p1');
      expect((partsUsed.first as Map)['qty'], 2);

      final moves = await firestore.collection('stockMovements').get();
      expect(
        moves.docs.where((d) => d.data()['type'] == 'out'),
        hasLength(1),
      );
    });

    testWidgets('logging more than on-hand is rejected; nothing is written',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.store,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.jobDetail('j1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('addPartBtn')));
      await tester.tap(find.byKey(const Key('addPartBtn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('partDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SR626 (5)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('partQtyField')), '10');
      await tester.tap(find.byKey(const Key('addPartConfirm')));
      await tester.pumpAndSettle();

      expect(find.text('Not enough stock for that change.'), findsOneWidget);

      final firestore = container.read(firestoreProvider);
      final part =
          (await firestore.collection('parts').doc('p1').get()).data()!;
      expect(part['onHand'], 5);
      final job = (await firestore.collection('jobs').doc('j1').get()).data()!;
      expect((job['partsUsed'] as List?) ?? const [], isEmpty);
      final moves = await firestore.collection('stockMovements').get();
      expect(moves.docs, isEmpty);
    });

    testWidgets('a technician can log a part on a job (stock decrements)',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        role: UserRole.technician,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.jobDetail('j1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('addPartBtn')));
      await tester.tap(find.byKey(const Key('addPartBtn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('partDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SR626 (5)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('partQtyField')), '1');
      await tester.tap(find.byKey(const Key('addPartConfirm')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final part =
          (await firestore.collection('parts').doc('p1').get()).data()!;
      expect(part['onHand'], 4);
    });

    testWidgets('a counter (front desk) does not see the add-part action',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: _jobs(),
        parts: [partDoc(id: 'p1', reference: 'SR626', onHand: 5)],
      );

      container.read(routerProvider).go(Routes.jobDetail('j1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jobDetailScreen')), findsOneWidget);
      expect(find.byKey(const Key('addPartBtn')), findsNothing);
      expect(find.byKey(const Key('noPartsUsed')), findsOneWidget);
    });
  });
}
