import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);

Future<void> _open(
  WidgetTester tester,
  ProviderContainer container,
  String id,
) async {
  container.read(routerProvider).go(Routes.jobDetail(id));
  await tester.pumpAndSettle();
}

void main() {
  group('JobDetailScreen', () {
    testWidgets('deliver is disabled with a reason when QC is incomplete',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'ready',
            dueAt: _future,
          ),
        ],
      );

      await _open(tester, container, 'j1');

      final button =
          tester.widget<FilledButton>(find.byKey(const Key('deliverBtn')));
      expect(button.onPressed, isNull);
      expect(find.byKey(const Key('deliverGateReason')), findsOneWidget);
    });

    testWidgets('deliver is enabled when QC complete and a photo exists',
        (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'ready',
            dueAt: _future,
            qc: completeQc,
            deliveryPhotos: const ['p.jpg'],
          ),
        ],
      );

      await _open(tester, container, 'j1');

      final button =
          tester.widget<FilledButton>(find.byKey(const Key('deliverBtn')));
      expect(button.onPressed, isNotNull);
      expect(find.byKey(const Key('deliverGateReason')), findsNothing);
    });

    testWidgets('toggling a QC switch saves it', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'in_repair',
            dueAt: _future,
          ),
        ],
      );

      await _open(tester, container, 'j1');
      await tester.ensureVisible(find.byKey(const Key('qc_timekeeping')));
      await tester.tap(find.byKey(const Key('qc_timekeeping')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final job = (await firestore.collection('jobs').doc('j1').get()).data()!;
      expect((job['qc'] as Map)['timekeeping'], true);
    });

    testWidgets('moving status updates the job', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'received',
            dueAt: _future,
          ),
        ],
      );

      await _open(tester, container, 'j1');
      await tester.ensureVisible(find.byKey(const Key('moveTo_diagnosed')));
      await tester.tap(find.byKey(const Key('moveTo_diagnosed')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final job = (await firestore.collection('jobs').doc('j1').get()).data()!;
      expect(job['status'], 'diagnosed');
    });

    testWidgets('delivering an eligible job sets it delivered', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'ready',
            dueAt: _future,
            qc: completeQc,
            deliveryPhotos: const ['p.jpg'],
          ),
        ],
      );

      await _open(tester, container, 'j1');
      await tester.ensureVisible(find.byKey(const Key('deliverBtn')));
      await tester.tap(find.byKey(const Key('deliverBtn')));
      await tester.pumpAndSettle();

      final firestore = container.read(firestoreProvider);
      final job = (await firestore.collection('jobs').doc('j1').get()).data()!;
      expect(job['status'], 'delivered');
    });

    testWidgets('shows not-found for a missing job', (tester) async {
      final container = await pumpBoardApp(tester);

      await _open(tester, container, 'ghost');

      expect(find.byKey(const Key('jobNotFound')), findsOneWidget);
    });
  });
}
