import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_type.dart';
import '../../domain/repositories/purchasing_repository.dart';

/// [PurchasingRepository] backed by Cloud Firestore.
class FirestorePurchasingRepository implements PurchasingRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestorePurchasingRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _firestore.collection(Collections.suppliers);
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(Collections.orders);

  @override
  Stream<List<Supplier>> watchSuppliers(String branchId) => _suppliers
      .where('branchId', isEqualTo: branchId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) _supplierFromDoc(d.id, d.data())]);

  @override
  Future<Result<String>> createSupplier({
    required String name,
    required SupplierType type,
    required String branchId,
    required String by,
    String? contact,
  }) async {
    try {
      final doc = _suppliers.doc();
      await doc.set(<String, dynamic>{
        'name': name,
        'type': type.toWire,
        'branchId': branchId,
        if (contact != null) 'contact': contact,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': by,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'supplier.create',
        entity: Collections.suppliers,
        entityId: doc.id,
        after: <String, dynamic>{'name': name},
      );
      return Ok(doc.id);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Stream<List<PurchaseOrder>> watchOrders(String branchId) => _orders
      .where('branchId', isEqualTo: branchId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) _orderFromDoc(d.id, d.data())]);

  @override
  Future<Result<PurchaseOrder>> getOrder(String id) async {
    try {
      final snap = await _orders.doc(id).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        return Err(NotFoundFailure('Order $id not found'));
      }
      return Ok(_orderFromDoc(snap.id, data));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<PurchaseOrder>> createOrder({
    required String supplierId,
    required String branchId,
    required List<OrderItem> items,
    required String by,
    DateTime? expectedAt,
  }) async {
    try {
      final order = PurchaseOrder(
        id: '',
        supplierId: supplierId,
        branchId: branchId,
        status: OrderStatus.placed,
        items: items,
        placedBy: by,
        expectedAt: expectedAt,
      );
      final doc = _orders.doc();
      await doc.set(<String, dynamic>{
        ..._orderToDoc(order),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': by,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final snap = await doc.get();
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'order.create',
        entity: Collections.orders,
        entityId: doc.id,
        after: <String, dynamic>{'supplierId': supplierId},
      );
      return Ok(_orderFromDoc(snap.id, snap.data()!));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<PurchaseOrder>> applyReceipt(
    String orderId,
    Map<String, int> receivedByPart,
    String by,
  ) async {
    try {
      final ref = _orders.doc(orderId);
      final snap = await ref.get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        return Err(NotFoundFailure('Order $orderId not found'));
      }
      final order = _orderFromDoc(snap.id, data);
      final updatedItems = [
        for (final item in order.items)
          _receiveInto(item, receivedByPart[item.partId] ?? 0),
      ];
      final updated = order.copyWith(items: updatedItems);
      final newStatus = updated.statusFromItems();
      await ref.update(<String, dynamic>{
        'items': [for (final i in updatedItems) _itemToMap(i)],
        'status': newStatus.toWire,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'order.receipt.${newStatus.toWire}',
        entity: Collections.orders,
        entityId: orderId,
        after: <String, dynamic>{'status': newStatus.toWire},
      );
      return Ok(updated.copyWith(status: newStatus));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  /// Adds [received] to a line's `qtyReceived`, capped at `qtyOrdered` (no
  /// over-receipt).
  OrderItem _receiveInto(OrderItem item, int received) {
    if (received <= 0) return item;
    final next = item.qtyReceived + received;
    final capped = next > item.qtyOrdered ? item.qtyOrdered : next;
    return item.copyWith(qtyReceived: capped);
  }

  Supplier _supplierFromDoc(String id, Map<String, dynamic> data) => Supplier(
        id: id,
        name: FirestoreConvert.toStr(data['name']),
        type: SupplierType.fromWire(data['type'] as String?),
        branchId: FirestoreConvert.toStr(data['branchId']),
        contact: data['contact'] as String?,
      );

  PurchaseOrder _orderFromDoc(String id, Map<String, dynamic> data) =>
      PurchaseOrder(
        id: id,
        supplierId: FirestoreConvert.toStr(data['supplierId']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        status: OrderStatus.fromWire(data['status'] as String?),
        items: _itemsFrom(data['items']),
        placedBy: data['placedBy'] as String?,
        approvedBy: data['approvedBy'] as String?,
        expectedAt: FirestoreConvert.toDateTime(data['expectedAt']),
        createdAt: FirestoreConvert.toDateTime(data['createdAt']),
        updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
      );

  Map<String, dynamic> _orderToDoc(PurchaseOrder order) => <String, dynamic>{
        'supplierId': order.supplierId,
        'branchId': order.branchId,
        'status': order.status.toWire,
        'items': [for (final i in order.items) _itemToMap(i)],
        if (order.placedBy != null) 'placedBy': order.placedBy,
        if (order.approvedBy != null) 'approvedBy': order.approvedBy,
        if (order.expectedAt != null)
          'expectedAt': FirestoreConvert.toTimestamp(order.expectedAt),
      };

  OrderItem _itemFromMap(Map<String, dynamic> data) => OrderItem(
        partId: FirestoreConvert.toStr(data['partId']),
        qtyOrdered: FirestoreConvert.toInt(data['qtyOrdered']),
        qtyReceived: FirestoreConvert.toInt(data['qtyReceived']),
        model: data['model'] as String?,
      );

  Map<String, dynamic> _itemToMap(OrderItem item) => <String, dynamic>{
        'partId': item.partId,
        'qtyOrdered': item.qtyOrdered,
        'qtyReceived': item.qtyReceived,
        if (item.model != null) 'model': item.model,
      };

  List<OrderItem> _itemsFrom(Object? value) => value is List
      ? [
          for (final e in value)
            if (e is Map<String, dynamic>) _itemFromMap(e),
        ]
      : const [];

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
