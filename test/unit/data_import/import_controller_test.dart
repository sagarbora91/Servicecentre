import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:service_centre_app/features/data_import/presentation/controllers/import_controller.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late ProviderContainer container;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    await fs.collection('users').doc('u1').set(<String, dynamic>{
      'name': 'Owner',
      'role': 'owner',
      'phone': '0',
      'active': true,
      'branchId': 'b1',
    });
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'owner@test.com'),
    );
    container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(fs),
      ],
    );
    addTearDown(container.dispose);
    // Warm the profile so the controller's uid/branch resolve.
    await container.read(currentUserProvider.future);
  });

  test('previewCustomers reflects the parse counts', () {
    container
        .read(importControllerProvider.notifier)
        .previewCustomers('name,phone\nAsha,111\n,222\n');

    final state = container.read(importControllerProvider);
    expect(state.preview!.kind, ImportKind.customers);
    expect(state.preview!.okCount, 1);
    expect(state.preview!.errors, hasLength(1));
  });

  test('commit writes valid customers and reports a duplicate', () async {
    // An existing customer makes the imported "111" a duplicate at write time.
    await fs.collection('customers').doc('c0').set(<String, dynamic>{
      'name': 'Existing',
      'phone': '111',
      'branchId': 'b1',
      'serviceCount': 0,
      'consentWhatsApp': false,
    });
    container
        .read(importControllerProvider.notifier)
        .previewCustomers('name,phone\nAsha,111\nBhau,222\n');

    await container.read(importControllerProvider.notifier).commit();

    final state = container.read(importControllerProvider);
    expect(state.outcome!.kind, ImportKind.customers);
    expect(state.outcome!.imported, 1);
    expect(state.outcome!.failed, 1);
    expect(state.outcome!.failures.single.failure, isA<ConflictFailure>());
    expect(state.outcome!.failures.single.label, contains('111'));

    final all = await fs.collection('customers').get();
    expect(all.docs, hasLength(2)); // Existing + Bhau
  });

  test('commit writes valid parts, converting rupees to paise', () async {
    container
        .read(importControllerProvider.notifier)
        .previewParts('reference,onHand,cost\nSR626,5,15\n');

    await container.read(importControllerProvider.notifier).commit();

    final state = container.read(importControllerProvider);
    expect(state.outcome!.kind, ImportKind.parts);
    expect(state.outcome!.imported, 1);

    final parts = await fs.collection('parts').get();
    expect(parts.docs, hasLength(1));
    expect(parts.docs.single.data()['reference'], 'SR626');
    expect(parts.docs.single.data()['onHand'], 5);
    expect(parts.docs.single.data()['costPaise'], 1500);
  });

  test('commit is a no-op without a preview', () async {
    await container.read(importControllerProvider.notifier).commit();

    expect(container.read(importControllerProvider).outcome, isNull);
  });
}
