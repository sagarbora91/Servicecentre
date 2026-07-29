import '../../../../core/errors/result.dart';
import '../entities/order_item.dart';
import '../entities/purchase_order.dart';
import '../entities/supplier.dart';
import '../entities/supplier_type.dart';

/// Contract for purchasing: suppliers and purchase orders with goods-receipt
/// (GRN). Lives in `domain` (no Firebase imports); the `data` implementation
/// adapts Cloud Firestore. The stock side of a receipt is applied separately by
/// `InventoryRepository.receiveGrn` so each part stays transactional.
abstract interface class PurchasingRepository {
  /// Streams the suppliers in [branchId], newest first.
  Stream<List<Supplier>> watchSuppliers(String branchId);

  /// Creates a supplier and returns its id.
  Future<Result<String>> createSupplier({
    required String name,
    required SupplierType type,
    required String branchId,
    required String by,
    String? contact,
  });

  /// Streams the purchase orders in [branchId], newest first.
  Stream<List<PurchaseOrder>> watchOrders(String branchId);

  /// Fetches a purchase order by id (`NotFoundFailure` if absent).
  Future<Result<PurchaseOrder>> getOrder(String id);

  /// Creates a [OrderStatus.placed] order for [supplierId] with [items].
  Future<Result<PurchaseOrder>> createOrder({
    required String supplierId,
    required String branchId,
    required List<OrderItem> items,
    required String by,
    DateTime? expectedAt,
  });

  /// Records a goods-receipt: adds [receivedByPart] quantities to each line's
  /// `qtyReceived` (capped at ordered) and updates the order status
  /// (partial/received) via [PurchaseOrder.statusFromItems]. Does **not** move
  /// stock — the caller applies `InventoryRepository.receiveGrn` per line.
  /// Returns the updated order.
  Future<Result<PurchaseOrder>> applyReceipt(
    String orderId,
    Map<String, int> receivedByPart,
    String by,
  );
}
