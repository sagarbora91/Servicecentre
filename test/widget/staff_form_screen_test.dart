import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/l10n/app_localizations.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:service_centre_app/features/auth/presentation/screens/staff_form_screen.dart';

AppUser _owner() => const AppUser(
      uid: 'owner1',
      name: 'Owner',
      role: UserRole.owner,
      phone: '1',
      active: true,
      branchId: 'b1',
    );

/// Pumps the form behind a host route so a successful save can pop back cleanly.
Future<void> _pumpForm(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  AppUser? existing,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        currentUserProvider
            .overrideWith((ref) => Stream<AppUser?>.value(_owner())),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) =>
                        StaffFormScreen(branchId: 'b1', existing: existing),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('StaffFormScreen', () {
    testWidgets('shows validation errors on empty submit', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpForm(tester, firestore: firestore);

      await tester.tap(find.byKey(const Key('saveStaffBtn')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter a phone number'), findsOneWidget);
      expect(find.text('Enter the sign-in account ID'), findsOneWidget);
    });

    testWidgets('create writes a staff document with the entered fields',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpForm(tester, firestore: firestore);

      await tester.enterText(
        find.byKey(const Key('staffUidField')),
        'newuid',
      );
      await tester.enterText(find.byKey(const Key('staffNameField')), 'Asha');
      await tester.enterText(find.byKey(const Key('staffPhoneField')), '555');
      await tester.enterText(
        find.byKey(const Key('staffEmailField')),
        'asha@shop.com',
      );

      // Pick a non-default role to prove the dropdown selection is applied.
      await tester.tap(find.byKey(const Key('staffRoleDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Store keeper').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveStaffBtn')));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('users').doc('newuid').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['name'], 'Asha');
      expect(data['phone'], '555');
      expect(data['email'], 'asha@shop.com');
      expect(data['role'], 'store');
      expect(data['active'], isTrue);
      expect(data['branchId'], 'b1');
      expect(data['createdBy'], 'owner1');
    });

    testWidgets('edit keeps uid read-only and preserves the active flag',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Seed an inactive member, then edit only the name.
      await firestore.collection('users').doc('s1').set(<String, dynamic>{
        'name': 'Old',
        'role': 'counter',
        'phone': '9',
        'active': false,
        'branchId': 'b1',
        'createdBy': 'orig',
      });

      await _pumpForm(
        tester,
        firestore: firestore,
        existing: const AppUser(
          uid: 's1',
          name: 'Old',
          role: UserRole.counter,
          phone: '9',
          active: false,
          branchId: 'b1',
        ),
      );

      // The uid field is shown but disabled in edit mode.
      final uidField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('staffUidField')),
          matching: find.byType(TextField),
        ),
      );
      expect(uidField.enabled, isFalse);

      await tester.enterText(find.byKey(const Key('staffNameField')), 'New');
      await tester.tap(find.byKey(const Key('saveStaffBtn')));
      await tester.pumpAndSettle();

      final data = (await firestore.collection('users').doc('s1').get()).data()!;
      expect(data['name'], 'New');
      // Saving a profile must not silently reactivate a disabled account.
      expect(data['active'], isFalse);
      // Merge preserves the original createdBy.
      expect(data['createdBy'], 'orig');
    });
  });
}
