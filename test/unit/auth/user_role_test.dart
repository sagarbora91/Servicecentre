import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/auth/domain/entities/user_role.dart';

void main() {
  group('UserRole.fromName', () {
    test('parses every known role by name', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromName(role.name), role);
      }
    });

    test('returns null for null, empty, or unknown names', () {
      expect(UserRole.fromName(null), isNull);
      expect(UserRole.fromName(''), isNull);
      expect(UserRole.fromName('wizard'), isNull);
    });
  });

  group('capabilities', () {
    test('canFinance is true only for owner and supervisor', () {
      expect(UserRole.owner.canFinance, isTrue);
      expect(UserRole.supervisor.canFinance, isTrue);
      expect(UserRole.counter.canFinance, isFalse);
      expect(UserRole.technician.canFinance, isFalse);
      expect(UserRole.store.canFinance, isFalse);
    });

    test('canQuote adds counter to the finance roles', () {
      expect(UserRole.owner.canQuote, isTrue);
      expect(UserRole.supervisor.canQuote, isTrue);
      expect(UserRole.counter.canQuote, isTrue);
      // Workshop/store do not prepare customer quotes.
      expect(UserRole.technician.canQuote, isFalse);
      expect(UserRole.store.canQuote, isFalse);
    });

    test('canManageUsers is true only for owner', () {
      expect(UserRole.owner.canManageUsers, isTrue);
      expect(UserRole.supervisor.canManageUsers, isFalse);
      expect(UserRole.counter.canManageUsers, isFalse);
      expect(UserRole.technician.canManageUsers, isFalse);
      expect(UserRole.store.canManageUsers, isFalse);
    });

    test('canManageInventory is true for owner, supervisor, and store', () {
      expect(UserRole.owner.canManageInventory, isTrue);
      expect(UserRole.supervisor.canManageInventory, isTrue);
      expect(UserRole.store.canManageInventory, isTrue);
      expect(UserRole.counter.canManageInventory, isFalse);
      expect(UserRole.technician.canManageInventory, isFalse);
    });

    test('canLogJobParts adds technician to the inventory roles', () {
      expect(UserRole.owner.canLogJobParts, isTrue);
      expect(UserRole.supervisor.canLogJobParts, isTrue);
      expect(UserRole.store.canLogJobParts, isTrue);
      expect(UserRole.technician.canLogJobParts, isTrue);
      // Counter is front-desk only — no parts writes.
      expect(UserRole.counter.canLogJobParts, isFalse);
    });
  });
}
