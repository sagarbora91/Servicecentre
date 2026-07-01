import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/inventory/domain/entities/stock_movement.dart';

void main() {
  group('StockMovementType.wireName', () {
    test('serializes in_ as the reserved word "in"', () {
      expect(StockMovementType.in_.wireName, 'in');
    });

    test('serializes every other value as its enum name', () {
      expect(StockMovementType.out.wireName, 'out');
      expect(StockMovementType.adjust.wireName, 'adjust');
      expect(StockMovementType.grn.wireName, 'grn');
      expect(StockMovementType.reserve.wireName, 'reserve');
      expect(StockMovementType.release.wireName, 'release');
    });
  });

  group('StockMovementType.fromWireName', () {
    test('parses the wire form "in" to in_', () {
      expect(StockMovementType.fromWireName('in'), StockMovementType.in_);
    });

    test('also accepts the raw enum name "in_" for in_', () {
      expect(StockMovementType.fromWireName('in_'), StockMovementType.in_);
    });

    test('round-trips wireName for every value', () {
      for (final type in StockMovementType.values) {
        expect(StockMovementType.fromWireName(type.wireName), type);
      }
    });

    test('parses the enum name for every value', () {
      for (final type in StockMovementType.values) {
        expect(StockMovementType.fromWireName(type.name), type);
      }
    });

    test('returns null for null, empty, or unrecognized input', () {
      expect(StockMovementType.fromWireName(null), isNull);
      expect(StockMovementType.fromWireName(''), isNull);
      expect(StockMovementType.fromWireName('teleport'), isNull);
    });
  });

  group('StockMovement', () {
    final at = DateTime.utc(2026, 6, 20, 10, 30);

    test('holds its fields', () {
      final movement = StockMovement(
        id: 'm1',
        partId: 'p1',
        type: StockMovementType.out,
        qty: 3,
        at: at,
        by: 'u1',
        branchId: 'b1',
        jobId: 'j1',
      );

      expect(movement.id, 'm1');
      expect(movement.partId, 'p1');
      expect(movement.type, StockMovementType.out);
      expect(movement.qty, 3);
      expect(movement.at, at);
      expect(movement.by, 'u1');
      expect(movement.branchId, 'b1');
      expect(movement.jobId, 'j1');
      expect(movement.orderId, isNull);
    });

    test('equality is value-based', () {
      final a = StockMovement(
        id: 'm1',
        partId: 'p1',
        type: StockMovementType.in_,
        qty: 5,
        at: at,
        by: 'u1',
        branchId: 'b1',
      );
      final same = StockMovement(
        id: 'm1',
        partId: 'p1',
        type: StockMovementType.in_,
        qty: 5,
        at: at,
        by: 'u1',
        branchId: 'b1',
      );
      final differentQty = a.copyWith(qty: 6);

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(differentQty));
    });
  });
}
