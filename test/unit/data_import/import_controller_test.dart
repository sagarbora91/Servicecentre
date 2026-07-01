import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/core/firebase/firebase_providers.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:service_centre_app/features/auth/presentation/providers/staff_providers.dart';
import 'package:service_centre_app/features/data_import/presentation/controllers/import_controller.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late ProviderContainer container;

  setUp(() {
    fs = FakeFirebaseFirestore();
    // Override the profile-derived providers directly: the auth StreamProvider
    // chain doesn't settle in a bare container (no widget pumping the event
    // loop). branchId drives the write; uid is unused by the assertions.
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fs),
        currentBranchIdProvider.overrideWithValue('b1'),
        currentUserProvider.overrideWith((_) => Stream<AppUser?>.value(null)),
      ],
    );
    addTearDown(container.dispose);
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
