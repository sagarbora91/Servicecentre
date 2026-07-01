import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/inventory/domain/entities/order_item.dart';
import 'package:service_centre_app/features/inventory/domain/entities/order_status.dart';
import 'package:service_centre_app/features/inventory/domain/entities/purchase_order.dart';
import 'package:service_centre_app/features/inventory/domain/entities/supplier_type.dart';

PurchaseOrder _order(List<OrderItem> items, {OrderStatus status = OrderStatus.placed}) =>
    PurchaseOrder(
      id: 'o1',
      supplierId: 's1',
      branchId: 'b1',
      status: status,
      items: items,
    );

void main() {
  group('OrderItem', () {
    test('qtyOutstanding and isFullyReceived track receipt progress', () {
      const partial = OrderItem(partId: 'p', qtyOrdered: 10, qtyReceived: 4);
      expect(partial.qtyOutstanding, 6);
      expect(partial.isFullyReceived, isFalse);

      const full = OrderItem(partId: 'p', qtyOrdered: 10, qtyReceived: 10);
      expect(full.qtyOutstanding, 0);
      expect(full.isFullyReceived, isTrue);
    });
  });

  group('PurchaseOrder.statusFromItems', () {
    test('is placed when nothing received', () {
      final o = _order(const [OrderItem(partId: 'p', qtyOrdered: 5)]);
      expect(o.statusFromItems(), OrderStatus.placed);
    });

    test('is partial when some received', () {
      final o = _order(
        const [OrderItem(partId: 'p', qtyOrdered: 5, qtyReceived: 2)],
      );
      expect(o.statusFromItems(), OrderStatus.partial);
    });

    test('is received when every line is full', () {
      final o = _order(const [
        OrderItem(partId: 'a', qtyOrdered: 5, qtyReceived: 5),
        OrderItem(partId: 'b', qtyOrdered: 3, qtyReceived: 3),
      ]);
      expect(o.statusFromItems(), OrderStatus.received);
    });

    test('a cancelled order stays cancelled', () {
      final o = _order(
        const [OrderItem(partId: 'p', qtyOrdered: 5, qtyReceived: 5)],
        status: OrderStatus.cancelled,
      );
      expect(o.statusFromItems(), OrderStatus.cancelled);
    });
  });

  group('enum wire round-trips', () {
    test('SupplierType and OrderStatus map to/from wire', () {
      for (final t in SupplierType.values) {
        expect(SupplierType.fromWire(t.toWire), t);
      }
      for (final s in OrderStatus.values) {
        expect(OrderStatus.fromWire(s.toWire), s);
      }
    });
  });
}
