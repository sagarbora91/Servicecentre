import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_take.freezed.dart';

/// One counted line of a [StockTake] (`stockTakes/{id}.lines`, BUILD_BRIEF.md
/// §5.1): the physical [counted] quantity against the [system] on-hand, with
/// the [variance] between them. freezed value type.
@freezed
abstract class StockTakeLine with _$StockTakeLine {
  /// Creates a stock-take line.
  const factory StockTakeLine({
    required String partId,
    required int counted,
    required int system,
  }) = _StockTakeLine;

  const StockTakeLine._();

  /// The variance (counted − system): positive = surplus, negative = shortfall.
  int get variance => counted - system;
}

/// A physical stock-count reconciliation (`stockTakes/{id}`, BUILD_BRIEF.md
/// §5.1). freezed value type; Firestore mapping lives in `data`.
@freezed
abstract class StockTake with _$StockTake {
  /// Creates a stock-take.
  const factory StockTake({
    required String id,
    required String branchId,
    required List<StockTakeLine> lines,
    DateTime? date,
    String? by,
  }) = _StockTake;

  const StockTake._();

  /// Whether any line differs from the system quantity.
  bool get hasVariance => lines.any((l) => l.variance != 0);

  /// The net variance across all lines.
  int get netVariance {
    var sum = 0;
    for (final line in lines) {
      sum += line.variance;
    }
    return sum;
  }
}
