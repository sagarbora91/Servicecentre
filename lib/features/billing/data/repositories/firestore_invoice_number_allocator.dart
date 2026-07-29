import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/repositories/invoice_number_allocator.dart';

/// [InvoiceNumberAllocator] backed by a transactional Firestore counter.
///
/// The counter lives at `counters/{branchId}_INV_{YYMM}` as `{seq:int}`,
/// separate from the jobNo counter so the two never collide. Allocation runs in
/// a transaction (CLAUDE.md #3) so concurrent billings never reuse a number.
/// The returned value is `INV-YYMM-NNNN` (sequence zero-padded to four digits),
/// resetting each month per branch.
class FirestoreInvoiceNumberAllocator implements InvoiceNumberAllocator {
  /// Creates the allocator with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreInvoiceNumberAllocator({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<Result<String>> nextInvoiceNumber(
    String branchId, {
    DateTime? now,
  }) async {
    try {
      final period = _period((now ?? DateTime.now()).toUtc());
      final ref = _firestore
          .collection(Collections.counters)
          .doc('${branchId}_INV_$period');
      final seq = await _firestore.runTransaction<int>((tx) async {
        final snap = await tx.get(ref);
        final current =
            snap.exists ? FirestoreConvert.toInt(snap.data()?['seq']) : 0;
        final next = current + 1;
        tx.set(
          ref,
          <String, dynamic>{
            'seq': next,
            'branchId': branchId,
            'period': period,
            'kind': 'invoice',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return next;
      });
      return Ok('INV-$period-${seq.toString().padLeft(4, '0')}');
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  String _period(DateTime t) {
    final yy = (t.year % 100).toString().padLeft(2, '0');
    final mm = t.month.toString().padLeft(2, '0');
    return '$yy$mm';
  }

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
