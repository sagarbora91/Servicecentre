import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:service_centre_app/app/app.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';

/// End-to-end auth + role flow.
///
/// Uses in-memory fakes (not the Firebase emulator) so the routing/role
/// behaviour is exercised without external services. Run with
/// `flutter test integration_test` on a device or emulator. The emulator-backed
/// rules flow is added in M2 when the data layer lands.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner logs in, reaches owner-only screen, then signs out',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').set(<String, dynamic>{
      'name': 'Owner',
      'role': 'owner',
      'phone': '0000000000',
      'active': true,
    });
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'u1', email: 'owner@test.com'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          firestoreProvider.overrideWithValue(firestore),
        ],
        child: const ServiceCentreApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Starts signed out -> login screen.
    expect(find.byKey(const Key('signInBtn')), findsOneWidget);

    // Sign in.
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'owner@test.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'secret',
    );
    await tester.tap(find.byKey(const Key('signInBtn')));
    await tester.pumpAndSettle();

    // Lands on the owner dashboard.
    expect(find.byKey(const Key('roleChip')), findsOneWidget);
    expect(find.byKey(const Key('openAdminBtn')), findsOneWidget);

    // Owner-only screen is reachable.
    await tester.tap(find.byKey(const Key('openAdminBtn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adminUsersScreen')), findsOneWidget);

    // Back home, then sign out -> login screen again.
    await tester.tap(find.byKey(const Key('placeholderBack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOutBtn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signInBtn')), findsOneWidget);
  });
}
