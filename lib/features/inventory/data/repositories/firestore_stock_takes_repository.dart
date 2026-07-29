import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../domain/entities/stock_take.dart';
import '../../domain/repositories/stock_takes_repository.dart';

/// [StockTakesRepository] backed by Cloud Firestore.
class FirestoreStockTakesRepository implements StockTakesRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestoreStockTakesRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _stockTakes =>
      _firestore.collection(Collections.stockTakes);

  @override
  Stream<List<StockTake>> watchStockTakes(String branchId) => _stockTakes
      .where('branchId', isEqualTo: branchId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) _fromDoc(d.id, d.data())]);

  @override
  Future<Result<StockTake>> recordStockTake({
    required String branchId,
    required Map<String, int> counts,
    required String by,
  }) async {
    try {
      final lines = <StockTakeLine>[];
      for (final entry in counts.entries) {
        final partSnap =
            await _firestore.collection(Collections.parts).doc(entry.key).get();
        final system = FirestoreConvert.toInt(partSnap.data()?['onHand']);
        lines.add(
          StockTakeLine(partId: entry.key, counted: entry.value, system: system),
        );
      }
      final doc = _stockTakes.doc();
      await doc.set(<String, dynamic>{
        'branchId': branchId,
        'lines': [for (final l in lines) _lineToMap(l)],
        'date': FieldValue.serverTimestamp(),
        'by': by,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': by,
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'stockTake.record',
        entity: Collections.stockTakes,
        entityId: doc.id,
        after: <String, dynamic>{'lineCount': lines.length},
      );
      return Ok(
        StockTake(id: doc.id, branchId: branchId, lines: lines, by: by),
      );
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  StockTake _fromDoc(String id, Map<String, dynamic> data) => StockTake(
        id: id,
        branchId: FirestoreConvert.toStr(data['branchId']),
        lines: _linesFrom(data['lines']),
        date: FirestoreConvert.toDateTime(data['date']),
        by: data['by'] as String?,
      );

  StockTakeLine _lineFromMap(Map<String, dynamic> data) => StockTakeLine(
        partId: FirestoreConvert.toStr(data['partId']),
        counted: FirestoreConvert.toInt(data['counted']),
        system: FirestoreConvert.toInt(data['system']),
      );

  Map<String, dynamic> _lineToMap(StockTakeLine line) => <String, dynamic>{
        'partId': line.partId,
        'counted': line.counted,
        'system': line.system,
        'variance': line.variance,
      };

  List<StockTakeLine> _linesFrom(Object? value) => value is List
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
