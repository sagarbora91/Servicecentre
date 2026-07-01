import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/auth/domain/entities/app_user.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';

void main() {
  group('AppUser.fromMap', () {
    test('parses a full document', () {
      final user = AppUser.fromMap('u1', <String, dynamic>{
        'name': 'Asha',
        'role': 'supervisor',
        'phone': '123',
        'active': true,
        'email': 'a@b.com',
        'branchId': 'b1',
      });

      expect(user, isNotNull);
      expect(user!.uid, 'u1');
      expect(user.name, 'Asha');
      expect(user.role, UserRole.supervisor);
      expect(user.phone, '123');
      expect(user.active, isTrue);
      expect(user.email, 'a@b.com');
      expect(user.branchId, 'b1');
    });

    test('returns null when the role is missing or unrecognized', () {
      expect(AppUser.fromMap('u1', <String, dynamic>{'name': 'X'}), isNull);
      expect(
        AppUser.fromMap('u1', <String, dynamic>{'role': 'wizard'}),
        isNull,
      );
    });

    test('defaults missing optional fields', () {
      final user = AppUser.fromMap('u1', <String, dynamic>{'role': 'counter'});

      expect(user, isNotNull);
      expect(user!.name, '');
      expect(user.phone, '');
      expect(user.active, isFalse);
      expect(user.email, isNull);
      expect(user.branchId, isNull);
    });
  });

  group('AppUser.toMap', () {
    test('omits null email and branchId', () {
      const user = AppUser(
        uid: 'u1',
        name: 'N',
        role: UserRole.owner,
        phone: '9',
        active: true,
      );

      final map = user.toMap();

      expect(map, <String, dynamic>{
        'name': 'N',
        'role': 'owner',
        'phone': '9',
        'active': true,
      });
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('branchId'), isFalse);
    });

    test('round-trips through fromMap for every role', () {
      for (final role in UserRole.values) {
        final original = AppUser(
          uid: 'u1',
          name: 'N',
          role: role,
          phone: '9',
          active: true,
          email: 'e@x.com',
          branchId: 'b1',
        );

        expect(AppUser.fromMap('u1', original.toMap()), original);
      }
    });
  });

  group('AppUser equality', () {
    test('is value-based', () {
      const a = AppUser(
        uid: 'u1',
        name: 'N',
        role: UserRole.owner,
        phone: '9',
        active: true,
      );
      const same = AppUser(
        uid: 'u1',
        name: 'N',
        role: UserRole.owner,
        phone: '9',
        active: true,
      );
      const differentRole = AppUser(
        uid: 'u1',
        name: 'N',
        role: UserRole.counter,
        phone: '9',
        active: true,
      );

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(differentRole));
    });
  });
}
