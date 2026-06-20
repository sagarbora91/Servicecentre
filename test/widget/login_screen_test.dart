import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/app/l10n/app_localizations.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/core/errors/result.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:service_centre_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:service_centre_app/features/auth/presentation/screens/login_screen.dart';

/// Minimal [AuthRepository] whose sign-in returns a fixed [Result].
class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository(this._signInResult);

  final Result<void> _signInResult;

  @override
  Stream<String?> authStateChanges() => Stream.value(null);

  @override
  String? get currentUid => null;

  @override
  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _signInResult;

  @override
  Future<Result<void>> signOut() async => const Ok(null);

  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(null);
}

Future<void> _pumpLogin(WidgetTester tester, Result<void> signInResult) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(_StubAuthRepository(signInResult)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows validation errors on empty submit', (tester) async {
      await _pumpLogin(tester, const Ok(null));

      await tester.tap(find.byKey(const Key('signInBtn')));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('shows an error message when sign-in fails', (tester) async {
      await _pumpLogin(
        tester,
        const Err(
          AuthFailure(AuthFailureReason.invalidCredentials, 'bad'),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'a@b.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('signInBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signInError')), findsOneWidget);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });

    testWidgets('shows no error on a successful sign-in', (tester) async {
      await _pumpLogin(tester, const Ok(null));

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'a@b.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'right',
      );
      await tester.tap(find.byKey(const Key('signInBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signInError')), findsNothing);
    });
  });
}
