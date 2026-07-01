import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/customers/domain/entities/customer.dart';

void main() {
  group('Customer', () {
    const base = Customer(
      id: 'c1',
      name: 'Asha',
      phone: '9000000000',
      serviceCount: 2,
      consentWhatsApp: true,
      branchId: 'b1',
    );

    test('holds its required fields and defaults optionals to null', () {
      expect(base.id, 'c1');
      expect(base.name, 'Asha');
      expect(base.phone, '9000000000');
      expect(base.serviceCount, 2);
      expect(base.consentWhatsApp, isTrue);
      expect(base.branchId, 'b1');
      expect(base.email, isNull);
      expect(base.address, isNull);
      expect(base.lastVisitAt, isNull);
      expect(base.createdAt, isNull);
      expect(base.createdBy, isNull);
      expect(base.updatedAt, isNull);
    });

    test('carries optional and audit fields when provided', () {
      final visit = DateTime.utc(2026, 6, 20, 9);
      final created = DateTime.utc(2026, 6, 1, 8);
      final updated = DateTime.utc(2026, 6, 19, 8);
      final full = Customer(
        id: 'c2',
        name: 'Ravi',
        phone: '8000000000',
        serviceCount: 0,
        consentWhatsApp: false,
        branchId: 'b1',
        email: 'ravi@example.com',
        address: 'MG Road',
        lastVisitAt: visit,
        createdAt: created,
        createdBy: 'u1',
        updatedAt: updated,
      );

      expect(full.email, 'ravi@example.com');
      expect(full.address, 'MG Road');
      expect(full.lastVisitAt, visit);
      expect(full.createdAt, created);
      expect(full.createdBy, 'u1');
      expect(full.updatedAt, updated);
    });

    test('equality is value-based', () {
      const same = Customer(
        id: 'c1',
        name: 'Asha',
        phone: '9000000000',
        serviceCount: 2,
        consentWhatsApp: true,
        branchId: 'b1',
      );
      const differentName = Customer(
        id: 'c1',
        name: 'Asha B',
        phone: '9000000000',
        serviceCount: 2,
        consentWhatsApp: true,
        branchId: 'b1',
      );

      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(differentName));
    });

    test('copyWith replaces only the named fields', () {
      final updated = base.copyWith(
        serviceCount: 3,
        lastVisitAt: DateTime.utc(2026, 6, 21),
        email: 'asha@example.com',
      );

      expect(updated.serviceCount, 3);
      expect(updated.lastVisitAt, DateTime.utc(2026, 6, 21));
      expect(updated.email, 'asha@example.com');
      // Untouched fields are preserved.
      expect(updated.id, 'c1');
      expect(updated.name, 'Asha');
      expect(updated.consentWhatsApp, isTrue);
    });
  });
}
