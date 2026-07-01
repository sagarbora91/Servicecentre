import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../../jobs/domain/entities/payment_status.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_line.dart';
import '../../domain/repositories/invoice_number_allocator.dart';
import '../../domain/repositories/invoices_repository.dart';
import '../../domain/services/gst_calculator.dart';

/// [InvoicesRepository] backed by Cloud Firestore.
///
/// Computes GST totals from the lines via [GstCalculator] and allocates the
/// invoice number through the injected [InvoiceNumberAllocator] before writing,
/// so a persisted invoice's totals are always internally consistent. Maps
/// documents to/from [Invoice] via `_fromDoc`/`_toDoc` (keeping `domain`
/// Firebase-free) and returns a [Result] so failures never throw across layers.
class FirestoreInvoicesRepository implements InvoicesRepository {
  /// Creates the repository with an injected [FirebaseFirestore] and
  /// [InvoiceNumberAllocator].
  FirestoreInvoicesRepository({
    required FirebaseFirestore firestore,
    required InvoiceNumberAllocator numberAllocator,
  })  : _firestore = firestore,
        _numbers = numberAllocator;

  final FirebaseFirestore _firestore;
  final InvoiceNumberAllocator _numbers;

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _firestore.collection(Collections.invoices);

  @override
  Stream<List<Invoice>> watchInvoicesForJob(String jobId) => _invoices
      .where('jobId', isEqualTo: jobId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) _fromDoc(d.id, d.data())]);

  @override
  Future<Result<Invoice>> getInvoice(String id) async {
    try {
      final snap = await _invoices.doc(id).get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        return Err(NotFoundFailure('Invoice $id not found'));
      }
      return Ok(_fromDoc(snap.id, data));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<Invoice>> createInvoice({
    required String jobId,
    required String branchId,
    required List<InvoiceLine> lines,
    required String createdBy,
    GstPlace place = GstPlace.intraState,
  }) async {
    try {
      final numberResult = await _numbers.nextInvoiceNumber(branchId);
      if (numberResult case Err(:final failure)) return Err(failure);
      final number = numberResult.valueOrNull!;

      final totals = GstCalculator.invoiceBreakdown(lines, place: place);
      final invoice = Invoice(
        id: '',
        jobId: jobId,
        number: number,
        branchId: branchId,
        lines: lines,
        taxablePaise: totals.taxablePaise,
        taxPaise: totals.taxPaise,
        totalPaise: totals.totalPaise,
        paymentStatus: PaymentStatus.unpaid,
        place: place,
      );

      final doc = _invoices.doc();
      await doc.set(<String, dynamic>{
        ..._toDoc(invoice),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final snap = await doc.get();
      await writeActivityLog(
        _firestore,
        actor: createdBy,
        action: 'invoice.create',
        entity: Collections.invoices,
        entityId: doc.id,
        after: <String, dynamic>{
          'number': number,
          'jobId': jobId,
          'totalPaise': totals.totalPaise,
        },
      );
      return Ok(_fromDoc(snap.id, snap.data()!));
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  @override
  Future<Result<void>> updatePaymentStatus(
    String id,
    PaymentStatus status,
    String by,
  ) async {
    try {
      final doc = _invoices.doc(id);
      if (!(await doc.get()).exists) {
        return Err(NotFoundFailure('Invoice $id not found'));
      }
      await doc.update(<String, dynamic>{
        'paymentStatus': status.toWire,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'invoice.paymentStatus.${status.toWire}',
        entity: Collections.invoices,
        entityId: id,
        after: <String, dynamic>{'paymentStatus': status.toWire},
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  Invoice _fromDoc(String id, Map<String, dynamic> data) => Invoice(
        id: id,
        jobId: FirestoreConvert.toStr(data['jobId']),
        number: FirestoreConvert.toStr(data['number']),
        branchId: FirestoreConvert.toStr(data['branchId']),
        lines: _linesFrom(data['lines']),
        taxablePaise: FirestoreConvert.toInt(data['taxablePaise']),
        taxPaise: FirestoreConvert.toInt(data['taxPaise']),
        totalPaise: FirestoreConvert.toInt(data['totalPaise']),
        paymentStatus:
            PaymentStatus.fromWire(data['paymentStatus'] as String?) ??
                PaymentStatus.unpaid,
        place: data['place'] == 'inter_state'
            ? GstPlace.interState
            : GstPlace.intraState,
        createdAt: FirestoreConvert.toDateTime(data['createdAt']),
        createdBy: data['createdBy'] as String?,
        updatedAt: FirestoreConvert.toDateTime(data['updatedAt']),
      );

  Map<String, dynamic> _toDoc(Invoice invoice) => <String, dynamic>{
        'jobId': invoice.jobId,
        'number': invoice.number,
        'branchId': invoice.branchId,
        'lines': [for (final l in invoice.lines) _lineToMap(l)],
        'taxablePaise': invoice.taxablePaise,
        'taxPaise': invoice.taxPaise,
        'totalPaise': invoice.totalPaise,
        'paymentStatus': invoice.paymentStatus.toWire,
        'place': invoice.place == GstPlace.interState
            ? 'inter_state'
            : 'intra_state',
      };

  InvoiceLine _lineFromMap(Map<String, dynamic> data) => InvoiceLine(
        desc: FirestoreConvert.toStr(data['desc']),
        qty: FirestoreConvert.toInt(data['qty']),
        ratePaise: FirestoreConvert.toInt(data['ratePaise']),
        gstPct: FirestoreConvert.toInt(data['gstPct']),
        hsn: data['hsn'] as String?,
      );

  Map<String, dynamic> _lineToMap(InvoiceLine line) => <String, dynamic>{
        'desc': line.desc,
        'qty': line.qty,
        'ratePaise': line.ratePaise,
        'gstPct': line.gstPct,
        if (line.hsn != null) 'hsn': line.hsn,
      };

  List<InvoiceLine> _linesFrom(Object? value) => value is List
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
