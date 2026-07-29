import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/repositories/job_no_allocator.dart';

/// [JobNoAllocator] backed by a transactional Firestore counter.
///
/// The counter lives at `counters/{branchId}_{YYMM}` as `{seq:int}`. Allocation
/// runs in a transaction (CLAUDE.md #3) so concurrent intakes never collide on
/// the same number. The returned value is `YYMM-NNNN` (sequence zero-padded to
/// four digits), resetting each month per branch.
class FirestoreJobNoAllocator implements JobNoAllocator {
  /// Creates the allocator with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreJobNoAllocator({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<Result<String>> nextJobNo(String branchId, {DateTime? now}) async {
    try {
      final period = _period((now ?? DateTime.now()).toUtc());
      final ref =
          _firestore.collection(Collections.counters).doc('${branchId}_$period');
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
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return next;
      });
      return Ok('$period-${seq.toString().padLeft(4, '0')}');
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  /// `YYMM` for [t] (two-digit year + zero-padded month).
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
