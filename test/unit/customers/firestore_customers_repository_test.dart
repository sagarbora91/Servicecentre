import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/customers/data/repositories/firestore_customers_repository.dart';

/// A Firestore whose `collection(...)` throws, used to drive the `try/catch`
/// branches that map unexpected errors to [UnexpectedFailure].
class _ThrowingFirestore extends Mock implements FirebaseFirestore {}

Future<String> _seedCustomer(
  FakeFirebaseFirestore fs, {
  required String branchId,
  required String name,
  required String phone,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) async {
  final ref = await fs.collection('customers').add(<String, dynamic>{
    'name': name,
    'phone': phone,
    'serviceCount': 0,
    'consentWhatsApp': false,
    'branchId': branchId,
    ...extra,
  });
  return ref.id;
}

void main() {
  late FakeFirebaseFirestore fs;
  late FirestoreCustomersRepository repo;

  setUp(() {
    fs = FakeFirebaseFirestore();
    repo = FirestoreCustomersRepository(fs);
  });

  group('watchCustomers', () {
    test('streams customers in the branch ordered by name', () async {
      await _seedCustomer(fs, branchId: 'b1', name: 'Charlie', phone: '3');
      await _seedCustomer(fs, branchId: 'b1', name: 'Alice', phone: '1');
      await _seedCustomer(fs, branchId: 'b1', name: 'Bob', phone: '2');
      // Different branch must be excluded.
      await _seedCustomer(fs, branchId: 'b2', name: 'Aaron', phone: '9');

      final customers = await repo.watchCustomers('b1').first;

      expect(customers.map((c) => c.name), <String>['Alice', 'Bob', 'Charlie']);
      expect(customers.every((c) => c.branchId == 'b1'), isTrue);
    });

    test('emits an empty list when the branch has no customers', () async {
      expect(await repo.watchCustomers('empty').first, isEmpty);
    });
  });

  group('getCustomer', () {
    test('returns Ok with the mapped customer when it exists', () async {
      final id = await _seedCustomer(
        fs,
        branchId: 'b1',
        name: 'Asha',
        phone: '9000000000',
        extra: <String, dynamic>{
          'serviceCount': 4,
          'consentWhatsApp': true,
          'email': 'asha@example.com',
          'address': 'MG Road',
          'createdBy': 'u1',
          'lastVisitAt': Timestamp.fromDate(DateTime.utc(2026, 6, 20, 9)),
        },
      );

      final result = await repo.getCustomer(id);

      expect(result.isOk, isTrue);
      final customer = result.valueOrNull!;
      expect(customer.id, id);
      expect(customer.name, 'Asha');
      expect(customer.serviceCount, 4);
      expect(customer.consentWhatsApp, isTrue);
      expect(customer.email, 'asha@example.com');
      expect(customer.address, 'MG Road');
      expect(customer.createdBy, 'u1');
      // Timestamp is converted to a UTC DateTime.
      expect(customer.lastVisitAt, DateTime.utc(2026, 6, 20, 9));
      expect(customer.lastVisitAt!.isUtc, isTrue);
    });

    test('defaults missing/absent fields when the doc is sparse', () async {
      // Only branchId stored; everything else missing.
      final ref = await fs
          .collection('customers')
          .add(<String, dynamic>{'branchId': 'b1'});

      final result = await repo.getCustomer(ref.id);

      expect(result.isOk, isTrue);
      final customer = result.valueOrNull!;
      expect(customer.name, '');
      expect(customer.phone, '');
      expect(customer.serviceCount, 0);
      expect(customer.consentWhatsApp, isFalse);
      expect(customer.email, isNull);
      expect(customer.address, isNull);
      expect(customer.lastVisitAt, isNull);
      expect(customer.createdAt, isNull);
      expect(customer.createdBy, isNull);
      expect(customer.updatedAt, isNull);
    });

    test('returns NotFoundFailure when the customer is absent', () async {
      final result = await repo.getCustomer('missing');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing = _ThrowingFirestore();
      when(() => throwing.collection(any())).thenThrow(Exception('boom'));
      final badRepo = FirestoreCustomersRepository(throwing);

      final result = await badRepo.getCustomer('x');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('createCustomer', () {
    test('creates a customer and stamps audit fields', () async {
      final result = await repo.createCustomer(
        branchId: 'b1',
        name: '  Asha  ',
        phone: '  9000000000  ',
        uid: 'u1',
        consentWhatsApp: true,
        email: 'asha@example.com',
        address: 'MG Road',
      );

      expect(result.isOk, isTrue);
      final customer = result.valueOrNull!;
      // Name and phone are trimmed.
      expect(customer.name, 'Asha');
      expect(customer.phone, '9000000000');
      expect(customer.serviceCount, 0);
      expect(customer.consentWhatsApp, isTrue);
      expect(customer.email, 'asha@example.com');
      expect(customer.address, 'MG Road');
      expect(customer.branchId, 'b1');

      // Persisted, with createdBy stamped.
      final stored = await fs.collection('customers').doc(customer.id).get();
      expect(stored.exists, isTrue);
      expect(stored.data()!['createdBy'], 'u1');
      expect(stored.data()!.containsKey('createdAt'), isTrue);
      expect(stored.data()!.containsKey('updatedAt'), isTrue);
    });

    test('omits email and address when not provided', () async {
      final result = await repo.createCustomer(
        branchId: 'b1',
        name: 'Ravi',
        phone: '8000000000',
        uid: 'u1',
      );

      expect(result.isOk, isTrue);
      final stored = await fs
          .collection('customers')
          .doc(result.valueOrNull!.id)
          .get();
      expect(stored.data()!.containsKey('email'), isFalse);
      expect(stored.data()!.containsKey('address'), isFalse);
      expect(result.valueOrNull!.consentWhatsApp, isFalse);
    });

    test('rejects a duplicate phone in the same branch (de-dupe)', () async {
      final first = await repo.createCustomer(
        branchId: 'b1',
        name: 'Asha',
        phone: '9000000000',
        uid: 'u1',
      );
      expect(first.isOk, isTrue);

      final dup = await repo.createCustomer(
        branchId: 'b1',
        name: 'Asha Again',
        phone: '9000000000',
        uid: 'u1',
      );

      expect(dup.isErr, isTrue);
      expect(dup.failureOrNull, isA<ConflictFailure>());
      expect(dup.failureOrNull!.message, contains('already exists'));

      // Only the first customer was persisted.
      final all = await fs
          .collection('customers')
          .where('phone', isEqualTo: '9000000000')
          .get();
      expect(all.docs, hasLength(1));
    });

    test('de-dupe trims the phone before comparing', () async {
      await repo.createCustomer(
        branchId: 'b1',
        name: 'Asha',
        phone: '9000000000',
        uid: 'u1',
      );

      final dup = await repo.createCustomer(
        branchId: 'b1',
        name: 'Asha',
        phone: '  9000000000  ',
        uid: 'u1',
      );

      expect(dup.isErr, isTrue);
    });

    test('allows the same phone in a different branch', () async {
      await repo.createCustomer(
        branchId: 'b1',
        name: 'Asha',
        phone: '9000000000',
        uid: 'u1',
      );

      final other = await repo.createCustomer(
        branchId: 'b2',
        name: 'Asha',
        phone: '9000000000',
        uid: 'u1',
      );

      expect(other.isOk, isTrue);
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing = _ThrowingFirestore();
      when(() => throwing.collection(any())).thenThrow(Exception('boom'));
      final badRepo = FirestoreCustomersRepository(throwing);

      final result = await badRepo.createCustomer(
        branchId: 'b1',
        name: 'X',
        phone: '1',
        uid: 'u1',
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('updateCustomer', () {
    test('writes only the provided fields and sets updatedAt', () async {
      final id = await _seedCustomer(
        fs,
        branchId: 'b1',
        name: 'Asha',
        phone: '9000000000',
        extra: <String, dynamic>{'serviceCount': 1},
      );

      final result = await repo.updateCustomer(
        id: id,
        name: '  Asha B  ',
        serviceCount: 5,
        consentWhatsApp: true,
        lastVisitAt: DateTime.utc(2026, 6, 21, 10),
      );

      expect(result.isOk, isTrue);
      final updated = result.valueOrNull!;
      expect(updated.name, 'Asha B'); // trimmed
      expect(updated.serviceCount, 5);
      expect(updated.consentWhatsApp, isTrue);
      expect(updated.lastVisitAt, DateTime.utc(2026, 6, 21, 10));
      // Untouched field preserved.
      expect(updated.phone, '9000000000');

      final stored = await fs.collection('customers').doc(id).get();
      expect(stored.data()!.containsKey('updatedAt'), isTrue);
    });

    test('updates phone, email and address when provided', () async {
      final id = await _seedCustomer(
        fs,
        branchId: 'b1',
        name: 'Asha',
        phone: '9000000000',
      );

      final result = await repo.updateCustomer(
        id: id,
        phone: '  8000000000 ',
        email: 'new@example.com',
        address: 'New Address',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.phone, '8000000000');
      expect(result.valueOrNull!.email, 'new@example.com');
      expect(result.valueOrNull!.address, 'New Address');
    });

    test('returns NotFoundFailure when the customer is absent', () async {
      final result = await repo.updateCustomer(id: 'missing', name: 'X');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing = _ThrowingFirestore();
      when(() => throwing.collection(any())).thenThrow(Exception('boom'));
      final badRepo = FirestoreCustomersRepository(throwing);

      final result = await badRepo.updateCustomer(id: 'x', name: 'Y');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('searchCustomers', () {
    setUp(() async {
      await _seedCustomer(fs, branchId: 'b1', name: 'Ashok', phone: '9111111');
      await _seedCustomer(fs, branchId: 'b1', name: 'Asha', phone: '9222222');
      await _seedCustomer(fs, branchId: 'b1', name: 'Bharat', phone: '9333333');
      // Same name prefix but different branch.
      await _seedCustomer(fs, branchId: 'b2', name: 'Ashwin', phone: '9444444');
    });

    test('returns no results for an empty query', () async {
      final result = await repo.searchCustomers('b1', '   ');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('matches a name prefix within the branch only', () async {
      final result = await repo.searchCustomers('b1', 'Ash');

      expect(result.isOk, isTrue);
      final names = result.valueOrNull!.map((c) => c.name).toList();
      expect(names, <String>['Asha', 'Ashok']); // sorted by name, b2 excluded
    });

    test('matches a phone prefix', () async {
      final result = await repo.searchCustomers('b1', '9222');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.map((c) => c.name), <String>['Asha']);
    });

    test('merges and de-dupes name and phone matches', () async {
      // 'Asha' matches by name; the merge de-dupes so she appears only once
      // even if a phone-prefix query would also return her.
      final result = await repo.searchCustomers('b1', 'Asha');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.single.name, 'Asha');
    });

    test('returns an empty list when nothing matches', () async {
      final result = await repo.searchCustomers('b1', 'Zzz');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing = _ThrowingFirestore();
      when(() => throwing.collection(any())).thenThrow(Exception('boom'));
      final badRepo = FirestoreCustomersRepository(throwing);

      final result = await badRepo.searchCustomers('b1', 'Ash');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('watchesForCustomer', () {
    test("streams a customer's watches ordered by brand", () async {
      await fs.collection('watches').add(<String, dynamic>{
        'customerId': 'c1',
        'brand': 'Titan',
        'model': 'Edge',
        'photos': <String>[],
        'branchId': 'b1',
      });
      await fs.collection('watches').add(<String, dynamic>{
        'customerId': 'c1',
        'brand': 'Casio',
        'model': 'G-Shock',
        'photos': <String>[],
        'branchId': 'b1',
      });
      // Another customer's watch must be excluded.
      await fs.collection('watches').add(<String, dynamic>{
        'customerId': 'c2',
        'brand': 'Apple',
        'model': 'Watch',
        'photos': <String>[],
        'branchId': 'b1',
      });

      final watches = await repo.watchesForCustomer('c1').first;

      expect(watches.map((w) => w.brand), <String>['Casio', 'Titan']);
      expect(watches.every((w) => w.customerId == 'c1'), isTrue);
    });

    test('emits an empty list when the customer has no watches', () async {
      expect(await repo.watchesForCustomer('c9').first, isEmpty);
    });
  });

  group('addWatch', () {
    test('adds a watch and stamps audit fields', () async {
      final result = await repo.addWatch(
        branchId: 'b1',
        customerId: 'c1',
        brand: '  Titan  ',
        model: '  Edge  ',
        uid: 'u1',
        serial: '  SN-1  ',
        warrantyUntil: DateTime.utc(2027, 1, 1),
        photos: const <String>['a.jpg'],
      );

      expect(result.isOk, isTrue);
      final watch = result.valueOrNull!;
      expect(watch.brand, 'Titan'); // trimmed
      expect(watch.model, 'Edge');
      expect(watch.serial, 'SN-1');
      expect(watch.customerId, 'c1');
      expect(watch.branchId, 'b1');
      expect(watch.photos, <String>['a.jpg']);
      // Timestamp round-trips to a UTC DateTime.
      expect(watch.warrantyUntil, DateTime.utc(2027, 1, 1));
      expect(watch.warrantyUntil!.isUtc, isTrue);

      final stored = await fs.collection('watches').doc(watch.id).get();
      expect(stored.data()!['createdBy'], 'u1');
      expect(stored.data()!.containsKey('createdAt'), isTrue);
    });

    test('omits serial and warranty when not provided; defaults photos',
        () async {
      final result = await repo.addWatch(
        branchId: 'b1',
        customerId: 'c1',
        brand: 'Casio',
        model: 'F-91W',
        uid: 'u1',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.serial, isNull);
      expect(result.valueOrNull!.warrantyUntil, isNull);
      expect(result.valueOrNull!.photos, isEmpty);

      final stored = await fs
          .collection('watches')
          .doc(result.valueOrNull!.id)
          .get();
      expect(stored.data()!.containsKey('serial'), isFalse);
      expect(stored.data()!.containsKey('warrantyUntil'), isFalse);
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing = _ThrowingFirestore();
      when(() => throwing.collection(any())).thenThrow(Exception('boom'));
      final badRepo = FirestoreCustomersRepository(throwing);

      final result = await badRepo.addWatch(
        branchId: 'b1',
        customerId: 'c1',
        brand: 'X',
        model: 'Y',
        uid: 'u1',
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('updateWatch', () {
    test('writes only the provided fields and sets updatedAt', () async {
      final ref = await fs.collection('watches').add(<String, dynamic>{
        'customerId': 'c1',
        'brand': 'Titan',
        'model': 'Edge',
        'photos': <String>['old.jpg'],
        'branchId': 'b1',
      });

      final result = await repo.updateWatch(
        id: ref.id,
        model: '  Raga  ',
        serial: ' SN-9 ',
        warrantyUntil: DateTime.utc(2028, 5, 5),
        photos: const <String>['new.jpg'],
      );

      expect(result.isOk, isTrue);
      final watch = result.valueOrNull!;
      expect(watch.model, 'Raga'); // trimmed
      expect(watch.serial, 'SN-9');
      expect(watch.warrantyUntil, DateTime.utc(2028, 5, 5));
      expect(watch.photos, <String>['new.jpg']);
      // Untouched field preserved.
      expect(watch.brand, 'Titan');

      final stored = await fs.collection('watches').doc(ref.id).get();
      expect(stored.data()!.containsKey('updatedAt'), isTrue);
    });

    test('returns NotFoundFailure when the watch is absent', () async {
      final result = await repo.updateWatch(id: 'missing', brand: 'X');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final throwing = _ThrowingFirestore();
      when(() => throwing.collection(any())).thenThrow(Exception('boom'));
      final badRepo = FirestoreCustomersRepository(throwing);

      final result = await badRepo.updateWatch(id: 'x', brand: 'Y');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
