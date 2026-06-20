import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';

class _ThrowingAuth extends Mock implements FirebaseAuth {}

void main() {
  group('FirebaseAuthRepository', () {
    test('signInWithEmail returns Ok on success', () async {
      final repo = FirebaseAuthRepository(
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1')),
        firestore: FakeFirebaseFirestore(),
      );

      final result = await repo.signInWithEmail(
        email: 'a@b.com',
        password: 'secret',
      );

      expect(result.isOk, isTrue);
    });

    test('signOut clears the current user', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1'),
      );
      final repo = FirebaseAuthRepository(
        auth: auth,
        firestore: FakeFirebaseFirestore(),
      );

      final result = await repo.signOut();

      expect(result.isOk, isTrue);
      expect(repo.currentUid, isNull);
    });

    test('watchUser emits the profile when the document exists', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set(<String, dynamic>{
        'name': 'Asha',
        'role': 'supervisor',
        'phone': '123',
        'active': true,
      });
      final repo = FirebaseAuthRepository(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );

      final user = await repo.watchUser('u1').first;

      expect(user, isNotNull);
      expect(user!.name, 'Asha');
      expect(user.role, UserRole.supervisor);
      expect(user.active, isTrue);
    });

    test('watchUser emits null when the document is missing', () async {
      final repo = FirebaseAuthRepository(
        auth: MockFirebaseAuth(),
        firestore: FakeFirebaseFirestore(),
      );

      final user = await repo.watchUser('missing').first;

      expect(user, isNull);
    });

    test('watchUser emits null when the role is unrecognized', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set(<String, dynamic>{
        'name': 'X',
        'role': 'wizard',
        'phone': '1',
        'active': true,
      });
      final repo = FirebaseAuthRepository(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );

      expect(await repo.watchUser('u1').first, isNull);
    });

    group('maps FirebaseAuthException codes to AuthFailureReason', () {
      late _ThrowingAuth auth;
      late FirebaseAuthRepository repo;

      setUp(() {
        auth = _ThrowingAuth();
        repo = FirebaseAuthRepository(
          auth: auth,
          firestore: FakeFirebaseFirestore(),
        );
      });

      Future<AuthFailureReason> reasonForCode(String code) async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: code));

        final result = await repo.signInWithEmail(
          email: 'a@b.com',
          password: 'x',
        );
        final failure = result.failureOrNull;
        expect(failure, isA<AuthFailure>());
        return (failure! as AuthFailure).reason;
      }

      test('wrong-password -> invalidCredentials', () async {
        expect(
          await reasonForCode('wrong-password'),
          AuthFailureReason.invalidCredentials,
        );
      });

      test('user-disabled -> userDisabled', () async {
        expect(
          await reasonForCode('user-disabled'),
          AuthFailureReason.userDisabled,
        );
      });

      test('network-request-failed -> network', () async {
        expect(
          await reasonForCode('network-request-failed'),
          AuthFailureReason.network,
        );
      });

      test('unrecognized code -> unknown', () async {
        expect(
          await reasonForCode('something-odd'),
          AuthFailureReason.unknown,
        );
      });
    });
  });
}
