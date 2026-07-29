import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);
final _past = DateTime.utc(2020, 1, 1);

void main() {
  group('BoardScreen', () {
    testWidgets('home Board button opens the board', (tester) async {
      await pumpBoardApp(tester);

      expect(find.byKey(const Key('openBoardBtn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('openBoardBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('boardScreen')), findsOneWidget);
    });

    testWidgets('renders all eight columns and the seeded cards',
        (tester) async {
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
          jobDoc(
            id: 'j2',
            jobNo: '2606-0002',
            customerId: 'c1',
            status: 'ready',
            dueAt: _future,
          ),
        ],
      );

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();

      for (final status in JobStatus.values) {
        expect(
          find.byKey(Key('boardColumnHeader_${status.wireName}')),
          findsOneWidget,
          reason: 'missing column ${status.wireName}',
        );
      }
      expect(find.byKey(const Key('jobCard_j1')), findsOneWidget);
      expect(find.byKey(const Key('jobCard_j2')), findsOneWidget);
      expect(find.text('2606-0001'), findsOneWidget);
      expect(find.text('Asha'), findsWidgets);
    });

    testWidgets('tapping a card opens the job detail', (tester) async {
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

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('jobCard_j1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jobDetailScreen')), findsOneWidget);
    });

    testWidgets('shows the empty state when the branch has no jobs',
        (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('boardEmpty')), findsOneWidget);
    });

    testWidgets('shows the no-branch state when the profile has no branch',
        (tester) async {
      final container = await pumpBoardApp(tester, branchId: null);

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('boardNoBranch')), findsOneWidget);
    });

    testWidgets('flags an overdue job', (tester) async {
      final container = await pumpBoardApp(
        tester,
        customers: [customerDoc(id: 'c1', name: 'Asha')],
        jobs: [
          jobDoc(
            id: 'j1',
            jobNo: '2606-0001',
            customerId: 'c1',
            status: 'received',
            dueAt: _past,
          ),
        ],
      );

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overdue_j1')), findsOneWidget);
    });
  });
}
