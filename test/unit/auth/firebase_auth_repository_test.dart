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

    test('authStateChanges emits the signed-in uid', () async {
      final repo = FirebaseAuthRepository(
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
        firestore: FakeFirebaseFirestore(),
      );

      expect(await repo.authStateChanges().first, 'u1');
      expect(repo.currentUid, 'u1');
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

      expect(await repo.watchUser('missing').first, isNull);
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

      const cases = <String, AuthFailureReason>{
        'invalid-credential': AuthFailureReason.invalidCredentials,
        'invalid-email': AuthFailureReason.invalidCredentials,
        'wrong-password': AuthFailureReason.invalidCredentials,
        'user-not-found': AuthFailureReason.invalidCredentials,
        'user-disabled': AuthFailureReason.userDisabled,
        'network-request-failed': AuthFailureReason.network,
        'too-many-requests': AuthFailureReason.tooManyRequests,
        'something-odd': AuthFailureReason.unknown,
      };

      for (final entry in cases.entries) {
        test('${entry.key} -> ${entry.value.name}', () async {
          expect(await reasonForCode(entry.key), entry.value);
        });
      }
    });

    group('maps unexpected (non-Firebase) errors to UnexpectedFailure', () {
      late _ThrowingAuth auth;
      late FirebaseAuthRepository repo;

      setUp(() {
        auth = _ThrowingAuth();
        repo = FirebaseAuthRepository(
          auth: auth,
          firestore: FakeFirebaseFirestore(),
        );
      });

      test('on signInWithEmail', () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('boom'));

        final result = await repo.signInWithEmail(
          email: 'a@b.com',
          password: 'x',
        );

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      });

      test('on signOut', () async {
        when(() => auth.signOut()).thenThrow(Exception('boom'));

        final result = await repo.signOut();

        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      });
    });
  });
}
