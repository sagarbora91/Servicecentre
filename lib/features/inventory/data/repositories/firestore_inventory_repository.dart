import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/part.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';

/// [InventoryRepository] backed by Cloud Firestore.
///
/// Every stock change runs inside a single [FirebaseFirestore.runTransaction]
/// that reads the part first, refuses to drive `onHand` below zero, and writes
/// the matching `stockMovements` entry atomically (CLAUDE.md #3, §7).
class FirestoreInventoryRepository implements InventoryRepository {
  /// Creates the repository with an injected Firestore instance so tests can
  /// pass a [FakeFirebaseFirestore].
  FirestoreInventoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _parts =>
      _firestore.collection(Collections.parts);

  CollectionReference<Map<String, dynamic>> get _movements =>
      _firestore.collection(Collections.stockMovements);

  @override
  Stream<List<Part>> watchParts(String branchId) => _parts
      .where('branchId', isEqualTo: branchId)
      .orderBy('category')
      .orderBy('reference')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((doc) => _partFromDoc(doc.id, doc.data())).toList(),
      );

  @override
  Future<Result<Part>> getPart(String id) async {
    try {
      final snap = await _parts.doc(id).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        return Err(NotFoundFailure('Part $id not found'));
      }
      return Ok(_partFromDoc(snap.id, data));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> createPart(Part part, {required String by}) async {
    try {
      final ref = _parts.doc();
      await ref.set({
        ..._partToDoc(part),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': by,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Ok(ref.id);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updatePart(Part part, {required String by}) async {
    try {
      await _parts.doc(part.id).update({
        ..._partToDoc(part),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> consume({
    required String partId,
    required int qty,
    required String jobId,
    required String by,
  }) =>
      _applyMovement(
        partId: partId,
        delta: -qty,
        movementQty: qty,
        type: StockMovementType.out,
        by: by,
        jobId: jobId,
      );

  @override
  Future<Result<void>> receiveStock({
    required String partId,
    required int qty,
    required String by,
  }) =>
      _applyMovement(
        partId: partId,
        delta: qty,
        movementQty: qty,
        type: StockMovementType.in_,
        by: by,
      );

  @override
  Future<Result<void>> adjustStock({
    required String partId,
    required int delta,
    required String by,
  }) =>
      _applyMovement(
        partId: partId,
        delta: delta,
        movementQty: delta,
        type: StockMovementType.adjust,
        by: by,
      );

  /// Shared transactional core for [consume]/[receiveStock]/[adjustStock].
  ///
  /// Reads the part, refuses to let `onHand` go below zero (returns
  /// `Err(InsufficientStockFailure)` writing nothing), then in the same
  /// transaction applies [delta] to `onHand` and creates a [type] movement of
  /// [movementQty]. The transaction body returns a [Result] so a business
  /// rejection commits no writes without being conflated with an infra error.
  Future<Result<void>> _applyMovement({
    required String partId,
    required int delta,
    required int movementQty,
    required StockMovementType type,
    required String by,
    String? jobId,
  }) async {
    final partRef = _parts.doc(partId);
    final movementRef = _movements.doc();
    try {
      return await _firestore.runTransaction<Result<void>>((txn) async {
        final snap = await txn.get(partRef);
        final data = snap.data();
        if (!snap.exists || data == null) {
          return Err(NotFoundFailure('Part $partId not found'));
        }
        final onHand = FirestoreConvert.toInt(data['onHand']);
        final newOnHand = onHand + delta;
        if (newOnHand < 0) {
          return Err(
            InsufficientStockFailure(
              'Part $partId has $onHand on hand; cannot apply $delta',
            ),
          );
        }

        txn
          ..update(partRef, {
            'onHand': newOnHand,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(movementRef, {
            'partId': partId,
            'type': type.wireName,
            'qty': movementQty,
            if (jobId != null) 'jobId': jobId,
            'at': FieldValue.serverTimestamp(),
            'by': by,
            'branchId': FirestoreConvert.toStr(data['branchId']),
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': by,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        return const Ok(null);
      });
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  /// Maps a `parts/{id}` document (its [id] and [data]) to a [Part].
  Part _partFromDoc(String id, Map<String, dynamic> data) => Part(
        id: id,
        category: FirestoreConvert.toStr(data['category']),
        reference: FirestoreConvert.toStr(data['reference']),
        binCode: FirestoreConvert.toStr(data['binCode']),
        onHand: FirestoreConvert.toInt(data['onHand']),
        reserved: FirestoreConvert.toInt(data['reserved']),
        minLevel: FirestoreConvert.toInt(data['minLevel']),
        reorderPoint: FirestoreConvert.toInt(data['reorderPoint']),
        serviceOnly: FirestoreConvert.toBool(data['serviceOnly']),
        costPaise: FirestoreConvert.toInt(data['costPaise']),
        mrpPaise: FirestoreConvert.toInt(data['mrpPaise']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        size: data['size'] as String?,
        mfgDate: FirestoreConvert.toDateTime(data['mfgDate']),
        createdAt: FirestoreConvert.toDateTime(data['createdAt']),
        createdBy: data['createdBy'] as String?,
        updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
      );

  /// Serializes the domain fields of [part] for Firestore. Audit timestamps are
  /// set by the caller via [FieldValue.serverTimestamp]; the doc id is omitted.
  Map<String, dynamic> _partToDoc(Part part) => {
        'category': part.category,
        'reference': part.reference,
        'binCode': part.binCode,
        'onHand': part.onHand,
        'reserved': part.reserved,
        'minLevel': part.minLevel,
        'reorderPoint': part.reorderPoint,
        'serviceOnly': part.serviceOnly,
        'costPaise': part.costPaise,
        'mrpPaise': part.mrpPaise,
        'branchId': part.branchId,
        if (part.size != null) 'size': part.size,
        if (part.mfgDate != null)
          'mfgDate': FirestoreConvert.toTimestamp(part.mfgDate),
      };
}
