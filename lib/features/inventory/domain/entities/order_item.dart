import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_item.freezed.dart';

/// A line on a purchase [Order] (`orders/{id}.items`, BUILD_BRIEF.md §5.1).
///
/// [qtyReceived] tracks goods-receipt progress against [qtyOrdered] (partial
/// GRN). freezed value type; Firestore mapping lives in `data`.
@freezed
abstract class OrderItem with _$OrderItem {
  /// Creates an order line.
  const factory OrderItem({
    required String partId,
    required int qtyOrdered,
    @Default(0) int qtyReceived,
    String? model,
  }) = _OrderItem;

  const OrderItem._();

  /// The quantity still outstanding on this line (never negative).
  int get qtyOutstanding {
    final remaining = qtyOrdered - qtyReceived;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether this line has been fully received.
  bool get isFullyReceived => qtyReceived >= qtyOrdered;
}
