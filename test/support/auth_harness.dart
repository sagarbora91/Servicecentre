import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/app.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';

/// Pumps the full app wired to fake Firebase services and signed in as a user
/// with the given [role]. Returns the container so tests can read providers
/// (e.g. the router) to drive navigation.
///
/// Pass `role: null` to simulate a signed-in account whose `users/{uid}`
/// document is missing (no profile).
Future<ProviderContainer> pumpAppSignedIn(
  WidgetTester tester, {
  required UserRole? role,
  bool active = true,
  String uid = 'u1',
}) async {
  final firestore = FakeFirebaseFirestore();
  if (role != null) {
    await firestore.collection('users').doc(uid).set(<String, dynamic>{
      'name': 'Test ${role.name}',
      'role': role.name,
      'phone': '0000000000',
      'active': active,
    });
  }
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid, email: 'staff@test.com'),
  );

  final container = ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(firestore),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ServiceCentreApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Pumps the app with no signed-in user (signed out).
Future<ProviderContainer> pumpAppSignedOut(WidgetTester tester) async {
  final firestore = FakeFirebaseFirestore();
  final auth = MockFirebaseAuth();

  final container = ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(firestore),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ServiceCentreApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
