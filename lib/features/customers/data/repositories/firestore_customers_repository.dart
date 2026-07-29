import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/watch.dart';
import '../../domain/repositories/customers_repository.dart';

/// High Unicode code point used as the upper bound for Firestore prefix
/// (`startsWith`) range queries: `value >= q AND value <= q + `.
const String _highSentinel = '';

/// [CustomersRepository] backed by Cloud Firestore.
///
/// Maps Firestore documents to `domain` entities via the private
/// `_customerFromDoc` / `_watchFromDoc` helpers (Timestamp <-> UTC DateTime via
/// [FirestoreConvert], keeping `domain` Firebase-free). Audit fields
/// (`createdAt`/`updatedAt`) are written with [FieldValue.serverTimestamp];
/// they read back `null` until the write commits, which the model tolerates.
class FirestoreCustomersRepository implements CustomersRepository {
  /// Creates the repository with an injected Firestore instance so tests can
  /// pass a `FakeFirebaseFirestore`.
  FirestoreCustomersRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection(Collections.customers);

  CollectionReference<Map<String, dynamic>> get _watches =>
      _firestore.collection(Collections.watches);

  @override
  Stream<List<Customer>> watchCustomers(String branchId) => _customers
      .where('branchId', isEqualTo: branchId)
      .orderBy('name')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => _customerFromDoc(d.id, d.data())).toList(),
      );

  @override
  Future<Result<Customer>> getCustomer(String id) async {
    try {
      final doc = await _customers.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return Err(NotFoundFailure('No customer with id $id'));
      }
      return Ok(_customerFromDoc(doc.id, data));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<Customer>> createCustomer({
    required String branchId,
    required String name,
    required String phone,
    required String uid,
    bool consentWhatsApp = false,
    String? email,
    String? address,
  }) async {
    final trimmedPhone = phone.trim();
    try {
      final existing = await _customers
          .where('branchId', isEqualTo: branchId)
          .where('phone', isEqualTo: trimmedPhone)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        // Phone de-dupe (BUILD_BRIEF Customers acceptance): a typed
        // ConflictFailure lets the UI branch on a duplicate cleanly.
        return Err(
          ConflictFailure(
            'A customer with phone $trimmedPhone already exists in this branch',
          ),
        );
      }

      final ref = _customers.doc();
      await ref.set(<String, dynamic>{
        'name': name.trim(),
        'phone': trimmedPhone,
        'serviceCount': 0,
        'consentWhatsApp': consentWhatsApp,
        'branchId': branchId,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final created = await ref.get();
      return Ok(
        _customerFromDoc(created.id, created.data() ?? <String, dynamic>{}),
      );
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<Customer>> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    bool? consentWhatsApp,
    int? serviceCount,
    DateTime? lastVisitAt,
  }) async {
    try {
      final ref = _customers.doc(id);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        return Err(NotFoundFailure('No customer with id $id'));
      }

      await ref.update(<String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (consentWhatsApp != null) 'consentWhatsApp': consentWhatsApp,
        if (serviceCount != null) 'serviceCount': serviceCount,
        if (lastVisitAt != null)
          'lastVisitAt': FirestoreConvert.toTimestamp(lastVisitAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updated = await ref.get();
      return Ok(
        _customerFromDoc(updated.id, updated.data() ?? <String, dynamic>{}),
      );
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Customer>>> searchCustomers(
    String branchId,
    String query,
  ) async {
    final term = query.trim();
    if (term.isEmpty) return const Ok(<Customer>[]);

    try {
      // Firestore can't OR across two fields, so run a prefix range query on
      // `name` and one on `phone`, then merge and de-dupe by doc id.
      final byName = _customers
          .where('branchId', isEqualTo: branchId)
          .where('name', isGreaterThanOrEqualTo: term)
          .where('name', isLessThanOrEqualTo: '$term$_highSentinel')
          .get();
      final byPhone = _customers
          .where('branchId', isEqualTo: branchId)
          .where('phone', isGreaterThanOrEqualTo: term)
          .where('phone', isLessThanOrEqualTo: '$term$_highSentinel')
          .get();
      final results = await Future.wait([byName, byPhone]);

      final merged = <String, Customer>{};
      for (final snap in results) {
        for (final doc in snap.docs) {
          merged[doc.id] = _customerFromDoc(doc.id, doc.data());
        }
      }
      final customers = merged.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return Ok(customers);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Watch>>> searchWatchesBySerial(
    String branchId,
    String query,
  ) async {
    final term = query.trim();
    if (term.isEmpty) return const Ok(<Watch>[]);

    try {
      final snap = await _watches
          .where('branchId', isEqualTo: branchId)
          .where('serial', isGreaterThanOrEqualTo: term)
          .where('serial', isLessThanOrEqualTo: '$term$_highSentinel')
          .get();
      return Ok(
        snap.docs.map((d) => _watchFromDoc(d.id, d.data())).toList(),
      );
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Stream<List<Watch>> watchesForCustomer(String customerId) => _watches
      .where('customerId', isEqualTo: customerId)
      .orderBy('brand')
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => _watchFromDoc(d.id, d.data())).toList(),
      );

  @override
  Future<Result<Watch>> addWatch({
    required String branchId,
    required String customerId,
    required String brand,
    required String model,
    required String uid,
    String? serial,
    DateTime? warrantyUntil,
    List<String> photos = const [],
  }) async {
    try {
      final ref = _watches.doc();
      await ref.set(<String, dynamic>{
        'customerId': customerId,
        'brand': brand.trim(),
        'model': model.trim(),
        'photos': photos,
        'branchId': branchId,
        if (serial != null) 'serial': serial.trim(),
        if (warrantyUntil != null)
          'warrantyUntil': FirestoreConvert.toTimestamp(warrantyUntil),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final created = await ref.get();
      return Ok(
        _watchFromDoc(created.id, created.data() ?? <String, dynamic>{}),
      );
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<Watch>> updateWatch({
    required String id,
    String? brand,
    String? model,
    String? serial,
    DateTime? warrantyUntil,
    List<String>? photos,
  }) async {
    try {
      final ref = _watches.doc(id);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        return Err(NotFoundFailure('No watch with id $id'));
      }

      await ref.update(<String, dynamic>{
        if (brand != null) 'brand': brand.trim(),
        if (model != null) 'model': model.trim(),
        if (serial != null) 'serial': serial.trim(),
        if (warrantyUntil != null)
          'warrantyUntil': FirestoreConvert.toTimestamp(warrantyUntil),
        if (photos != null) 'photos': photos,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updated = await ref.get();
      return Ok(
        _watchFromDoc(updated.id, updated.data() ?? <String, dynamic>{}),
      );
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  /// Builds a [Customer] from a Firestore document [id] and its [data].
  Customer _customerFromDoc(String id, Map<String, dynamic> data) => Customer(
        id: id,
        name: FirestoreConvert.toStr(data['name']),
        phone: FirestoreConvert.toStr(data['phone']),
        serviceCount: FirestoreConvert.toInt(data['serviceCount']),
        consentWhatsApp: FirestoreConvert.toBool(data['consentWhatsApp']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        email: data['email'] as String?,
        address: data['address'] as String?,
        lastVisitAt: FirestoreConvert.toDateTime(data['lastVisitAt']),
        createdAt: FirestoreConvert.toDateTime(data['createdAt']),
        createdBy: data['createdBy'] as String?,
        updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
      );

  /// Builds a [Watch] from a Firestore document [id] and its [data].
  Watch _watchFromDoc(String id, Map<String, dynamic> data) => Watch(
        id: id,
        customerId: FirestoreConvert.toStr(data['customerId']),
        brand: FirestoreConvert.toStr(data['brand']),
        model: FirestoreConvert.toStr(data['model']),
        photos: FirestoreConvert.toStringList(data['photos']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        serial: data['serial'] as String?,
        warrantyUntil: FirestoreConvert.toDateTime(data['warrantyUntil']),
        createdAt: FirestoreConvert.toDateTime(data['createdAt']),
        createdBy: data['createdBy'] as String?,
        updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
      );
}
