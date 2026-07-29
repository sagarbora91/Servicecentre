import '../../../../core/errors/result.dart';
import '../entities/stock_take.dart';

/// Contract for physical stock-count reconciliations (BUILD_BRIEF.md §12 M10:
/// "stock-take produces variance"). Lives in `domain` (no Firebase imports).
abstract interface class StockTakesRepository {
  /// Streams the stock-takes in [branchId], newest first.
  Stream<List<StockTake>> watchStockTakes(String branchId);

  /// Records a stock-take: for each part id in [counts], reads the current
  /// system on-hand, computes the variance, and writes an append-only
  /// `stockTakes` document. Does **not** adjust stock — reconciliation is a
  /// deliberate follow-up (`InventoryRepository.adjustStock` per variance).
  Future<Result<StockTake>> recordStockTake({
    required String branchId,
    required Map<String, int> counts,
    required String by,
  });
}
