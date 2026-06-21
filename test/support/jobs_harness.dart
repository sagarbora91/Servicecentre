import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/app.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';

/// A Firestore `customers/{id}` document map for seeding the board harness.
Map<String, dynamic> customerDoc({
  required String id,
  required String name,
  String phone = '1',
  String branchId = 'b1',
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'phone': phone,
      'branchId': branchId,
      'serviceCount': 0,
      'consentWhatsApp': false,
    };

/// A Firestore `jobs/{id}` document map for seeding the board harness. [status]
/// is a wire string (e.g. `received`, `awaiting_part`); [dueAt] is stored as a
/// Timestamp.
Map<String, dynamic> jobDoc({
  required String id,
  required String jobNo,
  required String customerId,
  required String status,
  required DateTime dueAt,
  String branchId = 'b1',
  String fault = 'fault',
  String workRequested = 'work',
  int tatTargetHrs = 24,
  String paymentStatus = 'unbilled',
  bool isRework = false,
}) =>
    <String, dynamic>{
      'id': id,
      'jobNo': jobNo,
      'customerId': customerId,
      'status': status,
      'dueAt': Timestamp.fromDate(dueAt.toUtc()),
      'branchId': branchId,
      'fault': fault,
      'workRequested': workRequested,
      'tatTargetHrs': tatTargetHrs,
      'paymentStatus': paymentStatus,
      'isRework': isRework,
    };

/// Pumps the full app signed in as [role], seeding [customers] and [jobs] into a
/// fake Firestore. Pass `branchId: null` to simulate a profile with no branch.
/// Returns the container so tests can drive the router.
Future<ProviderContainer> pumpBoardApp(
  WidgetTester tester, {
  UserRole role = UserRole.counter,
  String? branchId = 'b1',
  List<Map<String, dynamic>> jobs = const [],
  List<Map<String, dynamic>> customers = const [],
  String uid = 'u1',
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('users').doc(uid).set(<String, dynamic>{
    'name': 'Test ${role.name}',
    'role': role.name,
    'phone': '0000000000',
    'active': true,
    if (branchId != null) 'branchId': branchId,
  });
  for (final c in customers) {
    await firestore.collection('customers').doc(c['id'] as String).set(c);
  }
  for (final j in jobs) {
    await firestore.collection('jobs').doc(j['id'] as String).set(j);
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
