import 'package:freezed_annotation/freezed_annotation.dart';

import 'order_item.dart';
import 'order_status.dart';

part 'purchase_order.freezed.dart';

/// A purchase order to a supplier (`orders/{id}`, BUILD_BRIEF.md §5.1).
///
/// Named [PurchaseOrder] to avoid clashing with Dart's `Order`. Tracks its
/// [items] and derived receipt [status]. freezed value type; Firestore mapping
/// lives in `data`.
@freezed
abstract class PurchaseOrder with _$PurchaseOrder {
  /// Creates a purchase order.
  const factory PurchaseOrder({
    required String id,
    required String supplierId,
    required String branchId,
    required OrderStatus status,
    required List<OrderItem> items,
    String? placedBy,
    String? approvedBy,
    DateTime? expectedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _PurchaseOrder;

  const PurchaseOrder._();

  /// The receipt status implied by the current [items]: [OrderStatus.received]
  /// when every line is fully received, [OrderStatus.partial] when some (but not
  /// all) quantity is in, otherwise the order keeps its placed/draft status.
  /// [OrderStatus.cancelled] is preserved. Drives partial-GRN status updates.
  OrderStatus statusFromItems() {
    if (status == OrderStatus.cancelled) return OrderStatus.cancelled;
    final anyReceived = items.any((i) => i.qtyReceived > 0);
    final allReceived = items.isNotEmpty && items.every((i) => i.isFullyReceived);
    if (allReceived) return OrderStatus.received;
    if (anyReceived) return OrderStatus.partial;
    return status == OrderStatus.draft ? OrderStatus.draft : OrderStatus.placed;
  }
}
