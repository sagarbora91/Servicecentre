import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/inventory/domain/entities/stock_take.dart';

void main() {
  group('StockTakeLine.variance', () {
    test('is counted minus system (surplus positive, shortfall negative)', () {
      expect(
        const StockTakeLine(partId: 'p', counted: 12, system: 10).variance,
        2,
      );
      expect(
        const StockTakeLine(partId: 'p', counted: 7, system: 10).variance,
        -3,
      );
    });
  });

  group('StockTake', () {
    test('hasVariance and netVariance summarize the lines', () {
      const take = StockTake(
        id: 't1',
        branchId: 'b1',
        lines: [
          StockTakeLine(partId: 'a', counted: 12, system: 10), // +2
          StockTakeLine(partId: 'b', counted: 4, system: 5), // -1
        ],
      );
      expect(take.hasVariance, isTrue);
      expect(take.netVariance, 1);
    });

    test('hasVariance is false when every count matches', () {
      const take = StockTake(
        id: 't2',
        branchId: 'b1',
        lines: [StockTakeLine(partId: 'a', counted: 10, system: 10)],
      );
      expect(take.hasVariance, isFalse);
      expect(take.netVariance, 0);
    });
  });
}
