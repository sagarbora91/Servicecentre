import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/features/inventory/data/repositories/firestore_purchasing_repository.dart';
import 'package:service_centre_app/features/inventory/domain/entities/order_item.dart';
import 'package:service_centre_app/features/inventory/domain/entities/order_status.dart';
import 'package:service_centre_app/features/inventory/domain/entities/supplier_type.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirestorePurchasingRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestorePurchasingRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestorePurchasingRepository(firestore: firestore);
    });

    Future<String> newOrder() async {
      final created = await repo.createOrder(
        supplierId: 's1',
        branchId: 'b1',
        items: const [
          OrderItem(partId: 'p1', qtyOrdered: 10),
          OrderItem(partId: 'p2', qtyOrdered: 5),
        ],
        by: 'u1',
      );
      return created.valueOrNull!.id;
    }

    test('createSupplier stores and streams the supplier', () async {
      final id = await repo.createSupplier(
        name: 'Titan Spares',
        type: SupplierType.titan,
        branchId: 'b1',
        by: 'u1',
      );
      expect(id.valueOrNull, isNotNull);

      final list = await repo.watchSuppliers('b1').first;
      expect(list.single.name, 'Titan Spares');
      expect(list.single.type, SupplierType.titan);
    });

    test('createOrder starts placed with the ordered items', () async {
      final created = await repo.createOrder(
        supplierId: 's1',
        branchId: 'b1',
        items: const [OrderItem(partId: 'p1', qtyOrdered: 10)],
        by: 'u1',
      );

      final order = created.valueOrNull!;
      expect(order.status, OrderStatus.placed);
      expect(order.items.single.qtyOrdered, 10);
      expect(order.items.single.qtyReceived, 0);
    });

    test('a partial receipt moves the order to partial', () async {
      final id = await newOrder();
      expect(await repo.watchOrders('b1').first, hasLength(1));

      final result = await repo.applyReceipt(id, {'p1': 4}, 'u1');

      final order = result.valueOrNull!;
      expect(order.status, OrderStatus.partial);
      final p1 = order.items.firstWhere((i) => i.partId == 'p1');
      expect(p1.qtyReceived, 4);
    });

    test('receiving all lines moves the order to received (caps over-receipt)',
        () async {
      final id = await newOrder();

      await repo.applyReceipt(id, {'p1': 10}, 'u1');
      // Over-receive p2 (7 > 5) -> capped at 5; order fully received.
      final result = await repo.applyReceipt(id, {'p2': 7}, 'u1');

      final order = result.valueOrNull!;
      expect(order.status, OrderStatus.received);
      final p2 = order.items.firstWhere((i) => i.partId == 'p2');
      expect(p2.qtyReceived, 5);
    });

    test('applyReceipt on a missing order returns NotFound', () async {
      final result = await repo.applyReceipt('ghost', {'p1': 1}, 'u1');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('maps an unexpected error to UnexpectedFailure', () async {
      final mock = _MockFirestore();
      when(() => mock.collection('orders')).thenThrow(Exception('boom'));
      final mockRepo = FirestorePurchasingRepository(firestore: mock);

      final result = await mockRepo.getOrder('o1');
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
