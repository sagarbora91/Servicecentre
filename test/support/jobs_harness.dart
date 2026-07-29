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
  Map<String, dynamic>? qc,
  List<String> deliveryPhotos = const [],
  DateTime? createdAt,
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
      'deliveryPhotos': deliveryPhotos,
      'createdAt': Timestamp.fromDate((createdAt ?? DateTime.utc(2026)).toUtc()),
      if (qc != null) 'qc': qc,
    };

/// A Firestore `parts/{id}` document map for seeding the inventory screens.
/// Defaults make a plain, in-stock battery; override [onHand]/[reorderPoint] to
/// exercise the low-stock marker and override [branchId] for cross-branch tests.
Map<String, dynamic> partDoc({
  required String id,
  required String reference,
  String category = 'Battery',
  String binCode = 'A1',
  int onHand = 5,
  int reserved = 0,
  int minLevel = 1,
  int reorderPoint = 2,
  bool serviceOnly = false,
  int costPaise = 1000,
  int mrpPaise = 2500,
  String branchId = 'b1',
  String? size,
}) =>
    <String, dynamic>{
      'id': id,
      'category': category,
      'reference': reference,
      'binCode': binCode,
      'onHand': onHand,
      'reserved': reserved,
      'minLevel': minLevel,
      'reorderPoint': reorderPoint,
      'serviceOnly': serviceOnly,
      'costPaise': costPaise,
      'mrpPaise': mrpPaise,
      'branchId': branchId,
      if (size != null) 'size': size,
    };

/// A complete QC map (all checks passed) for delivery-gate tests.
const completeQc = <String, dynamic>{
  'timekeeping': true,
  'gasket': true,
  'glassClean': true,
  'strap': true,
  'crown': true,
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
  List<Map<String, dynamic>> parts = const [],
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
  for (final p in parts) {
    await firestore.collection('parts').doc(p['id'] as String).set(p);
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
