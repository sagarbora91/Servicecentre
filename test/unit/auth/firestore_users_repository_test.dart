import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/auth/data/repositories/firestore_users_repository.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';

/// A [FirebaseFirestore] whose `collection` always throws, to drive the
/// `UnexpectedFailure` branches of the repository's try/catch blocks.
class _ThrowingFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw StateError('boom');
}

AppUser _user(
  String uid, {
  String name = 'Name',
  UserRole role = UserRole.technician,
  bool active = true,
  String branchId = 'b1',
}) =>
    AppUser(
      uid: uid,
      name: name,
      role: role,
      phone: '123',
      active: active,
      branchId: branchId,
    );

void main() {
  group('FirestoreUsersRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreUsersRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreUsersRepository(firestore: firestore);
    });

    Future<Map<String, dynamic>?> readDoc(String uid) async =>
        (await firestore.collection('users').doc(uid).get()).data();

    group('upsertStaff', () {
      test('creates the document with audit fields, then updates it', () async {
        final created = await repo.upsertStaff(
          _user('u1', name: 'Asha'),
          by: 'owner1',
        );
        expect(created.isOk, isTrue);

        final afterCreate = await readDoc('u1');
        expect(afterCreate, isNotNull);
        expect(afterCreate!['name'], 'Asha');
        expect(afterCreate['role'], 'technician');
        expect(afterCreate['active'], isTrue);
        expect(afterCreate['branchId'], 'b1');
        expect(afterCreate['createdBy'], 'owner1');
        expect(afterCreate['createdAt'], isA<Timestamp>());
        expect(afterCreate['updatedAt'], isA<Timestamp>());
        final createdAt = afterCreate['createdAt'] as Timestamp;

        // Re-upsert as a different actor: updates fields but keeps createdAt /
        // createdBy from the original create (merge, create-only stamping).
        final updated = await repo.upsertStaff(
          _user('u1', name: 'Asha R', role: UserRole.counter),
          by: 'owner2',
        );
        expect(updated.isOk, isTrue);

        final afterUpdate = await readDoc('u1');
        expect(afterUpdate!['name'], 'Asha R');
        expect(afterUpdate['role'], 'counter');
        expect(afterUpdate['createdBy'], 'owner1');
        expect(afterUpdate['createdAt'], createdAt);
        expect(afterUpdate['updatedAt'], isA<Timestamp>());
      });

      test('round-trips back through getUser as an AppUser', () async {
        await repo.upsertStaff(
          _user('u1', name: 'Bina', role: UserRole.store),
          by: 'owner1',
        );

        final result = await repo.getUser('u1');

        expect(result.isOk, isTrue);
        final user = result.valueOrNull!;
        expect(user.uid, 'u1');
        expect(user.name, 'Bina');
        expect(user.role, UserRole.store);
        expect(user.branchId, 'b1');
      });

      test('maps an unexpected error to UnexpectedFailure', () async {
        final throwing = FirestoreUsersRepository(
          firestore: _ThrowingFirestore(),
        );

        final result = await throwing.upsertStaff(_user('u1'), by: 'owner1');

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      });
    });

    group('getUser', () {
      test('returns NotFoundFailure when the document is missing', () async {
        final result = await repo.getUser('missing');

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });

      test('returns NotFoundFailure when the role is unrecognized', () async {
        await firestore.collection('users').doc('u1').set(<String, dynamic>{
          'name': 'X',
          'role': 'wizard',
          'phone': '1',
          'active': true,
          'branchId': 'b1',
        });

        final result = await repo.getUser('u1');

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });

      test('maps an unexpected error to UnexpectedFailure', () async {
        final throwing = FirestoreUsersRepository(
          firestore: _ThrowingFirestore(),
        );

        final result = await throwing.getUser('u1');

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      });
    });

    group('watchStaff', () {
      test('streams active and inactive staff ordered by name', () async {
        await repo.upsertStaff(
          _user('u1', name: 'Chetan', active: true),
          by: 'owner1',
        );
        await repo.upsertStaff(
          _user('u2', name: 'Asha', active: false),
          by: 'owner1',
        );

        final staff = await repo.watchStaff('b1').first;

        expect(staff.map((u) => u.name), <String>['Asha', 'Chetan']);
        expect(staff.firstWhere((u) => u.uid == 'u2').active, isFalse);
      });

      test('filters by branchId', () async {
        await repo.upsertStaff(
          _user('u1', name: 'Here', branchId: 'b1'),
          by: 'owner1',
        );
        await repo.upsertStaff(
          _user('u2', name: 'There', branchId: 'b2'),
          by: 'owner1',
        );

        final staff = await repo.watchStaff('b1').first;

        expect(staff.map((u) => u.uid), <String>['u1']);
      });

      test('skips documents whose role is unrecognized', () async {
        await repo.upsertStaff(_user('u1', name: 'Good'), by: 'owner1');
        await firestore.collection('users').doc('u2').set(<String, dynamic>{
          'name': 'Bad',
          'role': 'wizard',
          'phone': '1',
          'active': true,
          'branchId': 'b1',
        });

        final staff = await repo.watchStaff('b1').first;

        expect(staff.map((u) => u.uid), <String>['u1']);
      });
    });

    group('setActive', () {
      test('flips the active flag and records updatedBy', () async {
        await repo.upsertStaff(_user('u1', active: true), by: 'owner1');

        final result = await repo.setActive('u1', active: false, by: 'owner2');

        expect(result.isOk, isTrue);
        final doc = await readDoc('u1');
        expect(doc!['active'], isFalse);
        expect(doc['updatedBy'], 'owner2');
        expect(doc['updatedAt'], isA<Timestamp>());

        // And back on again.
        final reactivate =
            await repo.setActive('u1', active: true, by: 'owner2');
        expect(reactivate.isOk, isTrue);
        expect((await readDoc('u1'))!['active'], isTrue);
      });

      test('returns NotFoundFailure when the document is missing', () async {
        final result = await repo.setActive('ghost', active: true, by: 'o1');

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });

      test('maps an unexpected error to UnexpectedFailure', () async {
        final throwing = FirestoreUsersRepository(
          firestore: _ThrowingFirestore(),
        );

        final result = await throwing.setActive('u1', active: true, by: 'o1');

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      });
    });
  });
}
