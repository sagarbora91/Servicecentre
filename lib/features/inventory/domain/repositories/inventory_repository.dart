import '../../../../core/errors/result.dart';
import '../entities/part.dart';

/// Contract for inventory: parts and transactional stock movements.
///
/// Lives in `domain`, so it has no Firebase imports; the implementation in
/// `data` adapts Cloud Firestore to this interface.
///
/// Every method that changes [Part.onHand] (or reserved) runs inside a single
/// Firestore transaction and records a matching `stockMovements` entry; stock
/// can never go negative (CLAUDE.md #3, BUILD_BRIEF.md §7).
abstract interface class InventoryRepository {
  /// Streams the parts in [branchId], ordered by category then reference
  /// (matches the `branchId, category, reference` composite index, §5.2).
  Stream<List<Part>> watchParts(String branchId);

  /// Fetches a single part by id. Returns `Err(NotFoundFailure)` if it does not
  /// exist.
  Future<Result<Part>> getPart(String id);

  /// Creates [part], stamping audit fields ([createdBy] from [by], server
  /// timestamps). Returns the stored id.
  Future<Result<String>> createPart(Part part, {required String by});

  /// Updates the mutable fields of an existing [part] (not stock; use the
  /// movement methods for that) and bumps `updatedAt`.
  Future<Result<void>> updatePart(Part part, {required String by});

  /// Consumes [qty] of part [partId] for [jobId].
  ///
  /// In one transaction: reads the part; if `onHand < qty` writes **nothing**
  /// and returns `Err(InsufficientStockFailure)`; otherwise decrements
  /// `onHand` by [qty] and creates an `out` movement in the same transaction.
  Future<Result<void>> consume({
    required String partId,
    required int qty,
    required String jobId,
    required String by,
  });

  /// Receives [qty] of part [partId] into stock.
  ///
  /// In one transaction: increments `onHand` by [qty] and creates an `in`
  /// movement.
  Future<Result<void>> receiveStock({
    required String partId,
    required int qty,
    required String by,
  });

  /// Adjusts on-hand of part [partId] by [delta] (which may be negative).
  ///
  /// In one transaction: guards that `onHand + delta >= 0` (otherwise writes
  /// nothing and returns `Err(InsufficientStockFailure)`), applies the delta,
  /// and creates an `adjust` movement.
  Future<Result<void>> adjustStock({
    required String partId,
    required int delta,
    required String by,
  });
}
