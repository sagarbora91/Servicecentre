import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/customers/domain/entities/watch.dart';

void main() {
  group('Watch', () {
    const base = Watch(
      id: 'w1',
      customerId: 'c1',
      brand: 'Titan',
      model: 'Edge',
      photos: <String>[],
      branchId: 'b1',
    );

    test('holds its required fields and defaults optionals to null', () {
      expect(base.id, 'w1');
      expect(base.customerId, 'c1');
      expect(base.brand, 'Titan');
      expect(base.model, 'Edge');
      expect(base.photos, isEmpty);
      expect(base.branchId, 'b1');
      expect(base.serial, isNull);
      expect(base.warrantyUntil, isNull);
      expect(base.createdAt, isNull);
      expect(base.createdBy, isNull);
      expect(base.updatedAt, isNull);
    });

    test('carries optional and audit fields when provided', () {
      final warranty = DateTime.utc(2027, 1, 1);
      final created = DateTime.utc(2026, 6, 1);
      final w = Watch(
        id: 'w2',
        customerId: 'c1',
        brand: 'Casio',
        model: 'G-Shock',
        photos: const <String>['a.jpg', 'b.jpg'],
        branchId: 'b1',
        serial: 'SN-123',
        warrantyUntil: warranty,
        createdAt: created,
        createdBy: 'u1',
        updatedAt: created,
      );

      expect(w.photos, <String>['a.jpg', 'b.jpg']);
      expect(w.serial, 'SN-123');
      expect(w.warrantyUntil, warranty);
      expect(w.createdAt, created);
      expect(w.createdBy, 'u1');
      expect(w.updatedAt, created);
    });

    test('equality is value-based', () {
      const same = Watch(
        id: 'w1',
        customerId: 'c1',
        brand: 'Titan',
        model: 'Edge',
        photos: <String>[],
        branchId: 'b1',
      );
      const differentModel = Watch(
        id: 'w1',
        customerId: 'c1',
        brand: 'Titan',
        model: 'Raga',
        photos: <String>[],
        branchId: 'b1',
      );

      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(differentModel));
    });

    test('copyWith replaces only the named fields', () {
      final updated = base.copyWith(
        model: 'Raga',
        serial: 'SN-9',
        photos: const <String>['x.jpg'],
      );

      expect(updated.model, 'Raga');
      expect(updated.serial, 'SN-9');
      expect(updated.photos, <String>['x.jpg']);
      expect(updated.id, 'w1');
      expect(updated.brand, 'Titan');
      expect(updated.customerId, 'c1');
    });
  });
}
