import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/l10n/app_localizations.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:service_centre_app/features/auth/presentation/screens/manage_staff_screen.dart';

AppUser _owner({String? branchId = 'b1'}) => AppUser(
      uid: 'owner1',
      name: 'Owner',
      role: UserRole.owner,
      phone: '1',
      active: true,
      branchId: branchId,
    );

Future<void> _seedStaff(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String name,
  String role = 'counter',
  bool active = true,
  String branchId = 'b1',
}) =>
    firestore.collection('users').doc(uid).set(<String, dynamic>{
      'name': name,
      'role': role,
      'phone': '555',
      'active': active,
      'branchId': branchId,
    });

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required AppUser currentUser,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        currentUserProvider
            .overrideWith((ref) => Stream<AppUser?>.value(currentUser)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ManageStaffScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ManageStaffScreen', () {
    testWidgets('lists branch staff with role and inactive badge',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedStaff(firestore, uid: 's1', name: 'Asha');
      await _seedStaff(
        firestore,
        uid: 's2',
        name: 'Bhau',
        role: 'technician',
        active: false,
      );

      await _pumpScreen(tester, firestore: firestore, currentUser: _owner());

      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('Bhau'), findsOneWidget);
      // Inactive member shows the badge; active one does not by itself.
      expect(find.textContaining('Inactive'), findsOneWidget);
      expect(find.byKey(const Key('addStaffFab')), findsOneWidget);
    });

    testWidgets('shows the empty state when the branch has no staff',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpScreen(tester, firestore: firestore, currentUser: _owner());

      expect(find.byKey(const Key('staffEmpty')), findsOneWidget);
    });

    testWidgets('shows the no-branch message and hides the FAB when no branch',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpScreen(
        tester,
        firestore: firestore,
        currentUser: _owner(branchId: null),
      );

      expect(find.byKey(const Key('noBranchMessage')), findsOneWidget);
      expect(find.byKey(const Key('addStaffFab')), findsNothing);
    });

    testWidgets('the FAB opens the add-staff form', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpScreen(tester, firestore: firestore, currentUser: _owner());

      await tester.tap(find.byKey(const Key('addStaffFab')));
      await tester.pumpAndSettle();

      // The form is identifiable by its uid field (not present on the list).
      expect(find.byKey(const Key('staffUidField')), findsOneWidget);
    });

    testWidgets('deactivating a member confirms then writes active=false',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedStaff(firestore, uid: 's1', name: 'Asha');

      await _pumpScreen(tester, firestore: firestore, currentUser: _owner());

      await tester.tap(find.byKey(const Key('staffMenu_s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears; confirm.
      expect(find.byKey(const Key('confirmDeactivateBtn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmDeactivateBtn')));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('users').doc('s1').get();
      expect(doc.data()!['active'], isFalse);
      expect(doc.data()!['updatedBy'], 'owner1');
    });

    testWidgets('cancelling the deactivate dialog leaves the member active',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedStaff(firestore, uid: 's1', name: 'Asha');

      await _pumpScreen(tester, firestore: firestore, currentUser: _owner());

      await tester.tap(find.byKey(const Key('staffMenu_s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('users').doc('s1').get();
      expect(doc.data()!['active'], isTrue);
    });
  });
}
