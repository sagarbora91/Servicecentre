import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';
import 'package:service_centre_app/features/auth/presentation/auth_guard.dart';

AppUser _user(UserRole role, {bool active = true}) => AppUser(
      uid: 'u1',
      name: 'Test',
      role: role,
      phone: '0',
      active: active,
    );

void main() {
  group('resolveRedirect', () {
    test('stays put while auth is still loading', () {
      final to = resolveRedirect(
        authLoading: true,
        uid: null,
        user: null,
        location: Routes.billing,
      );
      expect(to, isNull);
    });

    group('signed out', () {
      test('protected route redirects to login', () {
        final to = resolveRedirect(
          authLoading: false,
          uid: null,
          user: null,
          location: Routes.home,
        );
        expect(to, Routes.login);
      });

      test('login route is allowed', () {
        final to = resolveRedirect(
          authLoading: false,
          uid: null,
          user: null,
          location: Routes.login,
        );
        expect(to, isNull);
      });
    });

    group('signed in', () {
      test('login route redirects to home', () {
        final to = resolveRedirect(
          authLoading: false,
          uid: 'u1',
          user: _user(UserRole.counter),
          location: Routes.login,
        );
        expect(to, Routes.home);
      });

      test('home is allowed for any signed-in user', () {
        for (final role in UserRole.values) {
          final to = resolveRedirect(
            authLoading: false,
            uid: 'u1',
            user: _user(role),
            location: Routes.home,
          );
          expect(to, isNull, reason: 'home blocked for ${role.name}');
        }
      });

      test('billing allows only finance roles, bounces the rest', () {
        final allowed = {UserRole.owner, UserRole.supervisor};
        for (final role in UserRole.values) {
          final to = resolveRedirect(
            authLoading: false,
            uid: 'u1',
            user: _user(role),
            location: Routes.billing,
          );
          expect(
            to,
            allowed.contains(role) ? isNull : Routes.home,
            reason: 'billing guard wrong for ${role.name}',
          );
        }
      });

      test('admin users allows only the owner', () {
        for (final role in UserRole.values) {
          final to = resolveRedirect(
            authLoading: false,
            uid: 'u1',
            user: _user(role),
            location: Routes.adminUsers,
          );
          expect(
            to,
            role == UserRole.owner ? isNull : Routes.home,
            reason: 'admin guard wrong for ${role.name}',
          );
        }
      });

      test('inactive owner is bounced from a guarded route', () {
        final to = resolveRedirect(
          authLoading: false,
          uid: 'u1',
          user: _user(UserRole.owner, active: false),
          location: Routes.adminUsers,
        );
        expect(to, Routes.home);
      });

      test('signed in without a profile is bounced from guarded routes', () {
        final to = resolveRedirect(
          authLoading: false,
          uid: 'u1',
          user: null,
          location: Routes.billing,
        );
        expect(to, Routes.home);
      });
    });
  });

  group('requiredRolesFor', () {
    test('matches sub-paths of a guarded route', () {
      expect(
        requiredRolesFor('${Routes.adminUsers}/u9'),
        {UserRole.owner},
      );
    });

    test('returns null for unguarded routes', () {
      expect(requiredRolesFor(Routes.home), isNull);
    });
  });
}
