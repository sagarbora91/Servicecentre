import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/estimate.dart';
import '../../domain/entities/estimate_line.dart';
import '../../domain/entities/estimate_status.dart';
import '../../domain/repositories/estimates_repository.dart';

/// [EstimatesRepository] backed by Cloud Firestore.
///
/// Maps documents to/from [Estimate] via the private `_fromDoc`/`_toDoc`
/// helpers (keeping `domain` Firebase-free) and wraps every one-shot write in
/// `try/catch`, returning a [Result] so failures never throw across layers.
class FirestoreEstimatesRepository implements EstimatesRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreEstimatesRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _estimates =>
      _firestore.collection(Collections.estimates);

  @override
  Stream<List<Estimate>> watchEstimatesForJob(String jobId) => _estimates
      .where('jobId', isEqualTo: jobId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) _fromDoc(d.id, d.data())]);

  @override
  Future<Result<Estimate>> createEstimate({
    required String jobId,
    required String branchId,
    required List<EstimateLine> lines,
    required String createdBy,
  }) async {
    try {
      final draft = Estimate(
        id: '',
        jobId: jobId,
        branchId: branchId,
        lines: lines,
        totalPaise: 0,
        status: EstimateStatus.draft,
      );
      final doc = _estimates.doc();
      await doc.set(<String, dynamic>{
        ..._toDoc(draft),
        // Persist the total derived from the lines (source of truth).
        'totalPaise': draft.computedTotalPaise,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final snap = await doc.get();
      await writeActivityLog(
        _firestore,
        actor: createdBy,
        action: 'estimate.create',
        entity: Collections.estimates,
        entityId: doc.id,
        after: <String, dynamic>{
          'jobId': jobId,
          'totalPaise': draft.computedTotalPaise,
        },
      );
      return Ok(_fromDoc(snap.id, snap.data()!));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<void>> updateLines(
    String id,
    List<EstimateLine> lines,
    String by,
  ) async {
    try {
      final doc = _estimates.doc(id);
      if (!(await doc.get()).exists) {
        return Err(NotFoundFailure('Estimate $id not found'));
      }
      final total = _totalOf(lines);
      await doc.update(<String, dynamic>{
        'lines': [for (final l in lines) _lineToMap(l)],
        'totalPaise': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'estimate.updateLines',
        entity: Collections.estimates,
        entityId: id,
        after: <String, dynamic>{'totalPaise': total},
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<void>> setStatus(
    String id,
    EstimateStatus to,
    String by, {
    String? approvedVia,
  }) async {
    try {
      final doc = _estimates.doc(id);
      if (!(await doc.get()).exists) {
        return Err(NotFoundFailure('Estimate $id not found'));
      }
      await doc.update(<String, dynamic>{
        'status': to.toWire,
        if (to == EstimateStatus.approved)
          'approvedAt': FieldValue.serverTimestamp(),
        if (to == EstimateStatus.approved && approvedVia != null)
          'approvedVia': approvedVia,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'estimate.status.${to.toWire}',
        entity: Collections.estimates,
        entityId: id,
        after: <String, dynamic>{'status': to.toWire},
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  int _totalOf(List<EstimateLine> lines) {
    var sum = 0;
    for (final line in lines) {
      sum += line.amountPaise;
    }
    return sum;
  }

  Estimate _fromDoc(String id, Map<String, dynamic> data) => Estimate(
        id: id,
        jobId: FirestoreConvert.toStr(data['jobId']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        lines: _linesFrom(data['lines']),
        totalPaise: FirestoreConvert.toInt(data['totalPaise']),
        status: EstimateStatus.fromWire(data['status'] as String?) ??
            EstimateStatus.draft,
        approvedVia: data['approvedVia'] as String?,
        approvedAt: FirestoreConvert.toDateTime(data['approvedAt']),
        createdAt: FirestoreConvert.toDateTime(data['createdAt']),
        createdBy: data['createdBy'] as String?,
        updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
      );

  Map<String, dynamic> _toDoc(Estimate estimate) => <String, dynamic>{
        'jobId': estimate.jobId,
        'branchId': estimate.branchId,
        'lines': [for (final l in estimate.lines) _lineToMap(l)],
        'totalPaise': estimate.totalPaise,
        'status': estimate.status.toWire,
      };

  EstimateLine _lineFromMap(Map<String, dynamic> data) => EstimateLine(
        desc: FirestoreConvert.toStr(data['desc']),
        amountPaise: FirestoreConvert.toInt(data['amountPaise']),
      );

  Map<String, dynamic> _lineToMap(EstimateLine line) => <String, dynamic>{
        'desc': line.desc,
        'amountPaise': line.amountPaise,
      };

  List<EstimateLine> _linesFrom(Object? value) => value is List
      ? [
          for (final e in value)
            if (e is Map<String, dynamic>) _lineFromMap(e),
        ]
      : const [];

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
