import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/router.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

import '../support/jobs_harness.dart';

final _future = DateTime.utc(2999, 1, 1);

void main() {
  group('JobSearchScreen', () {
    testWidgets('the board search icon opens search', (tester) async {
      final container = await pumpBoardApp(tester);

      container.read(routerProvider).go(Routes.board);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boardSearchBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jobSearchScreen')), findsOneWidget);
      expect(find.byKey(const Key('searchPrompt')), findsOneWidget);
    });

    testWidgets('typing a jobNo finds the job and opens it', (tester) async {
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

      container.read(routerProvider).go(Routes.jobSearch);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('jobSearchField')), '2606');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('searchResult_j1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('searchResult_j1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('jobDetailScreen')), findsOneWidget);
    });

    testWidgets('a non-matching query shows no results', (tester) async {
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

      container.read(routerProvider).go(Routes.jobSearch);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('jobSearchField')), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('searchNoResults')), findsOneWidget);
    });
  });
}
