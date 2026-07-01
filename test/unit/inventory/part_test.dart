import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/inventory/domain/entities/part.dart';

Part _part({
  int onHand = 0,
  int reserved = 0,
  int reorderPoint = 0,
}) =>
    Part(
      id: 'p1',
      category: 'Battery',
      reference: 'SR626',
      binCode: 'A1',
      onHand: onHand,
      reserved: reserved,
      minLevel: 1,
      reorderPoint: reorderPoint,
      serviceOnly: false,
      costPaise: 1000,
      mrpPaise: 2500,
      branchId: 'b1',
    );

void main() {
  group('Part.available', () {
    test('is on-hand minus reserved', () {
      expect(_part(onHand: 10, reserved: 3).available, 7);
    });

    test('floors at zero when reserved exceeds on-hand', () {
      expect(_part(onHand: 2, reserved: 5).available, 0);
    });

    test('is zero when nothing on hand', () {
      expect(_part().available, 0);
    });
  });

  group('Part.isBelowReorder', () {
    test('is true below the reorder point', () {
      expect(_part(onHand: 1, reorderPoint: 5).isBelowReorder, isTrue);
    });

    test('is true at exactly the reorder point (§9 edge case)', () {
      expect(_part(onHand: 5, reorderPoint: 5).isBelowReorder, isTrue);
    });

    test('is false above the reorder point', () {
      expect(_part(onHand: 6, reorderPoint: 5).isBelowReorder, isFalse);
    });
  });

  group('Part', () {
    test('keeps money as integer paise and dates as UTC', () {
      final mfg = DateTime.utc(2025);
      final part = _part(onHand: 4).copyWith(
        costPaise: 12345,
        mrpPaise: 67890,
        size: '20mm',
        mfgDate: mfg,
      );

      expect(part.costPaise, 12345);
      expect(part.mrpPaise, 67890);
      expect(part.size, '20mm');
      expect(part.mfgDate, mfg);
      expect(part.mfgDate!.isUtc, isTrue);
    });

    test('equality is value-based', () {
      final a = _part(onHand: 4);
      final same = _part(onHand: 4);
      final different = _part(onHand: 9);

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(different));
    });
  });
}
