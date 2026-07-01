import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/collections.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/firebase/activity_log.dart';
import '../../../../core/firebase/converters.dart';
import '../../../jobs/domain/entities/payment_status.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_mode.dart';
import '../../domain/repositories/payments_repository.dart';

/// [PaymentsRepository] backed by Cloud Firestore.
///
/// [recordPayment] runs inside a Firestore transaction (CLAUDE.md #3): it reads
/// the invoice's running `amountPaidPaise`, refuses to over-collect (returning
/// an `Err` and writing nothing), and otherwise atomically appends the payment
/// and advances the invoice's paid total + `paymentStatus`. The running total
/// lives on the invoice so the check needs a single doc read (a transaction
/// cannot run a query over the payments collection).
class FirestorePaymentsRepository implements PaymentsRepository {
  /// Creates the repository with an injected [FirebaseFirestore] so tests can
  /// pass a fake.
  FirestorePaymentsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection(Collections.payments);

  DocumentReference<Map<String, dynamic>> _invoice(String id) =>
      _firestore.collection(Collections.invoices).doc(id);

  @override
  Stream<List<Payment>> watchPaymentsForInvoice(String invoiceId) => _payments
      .where('invoiceId', isEqualTo: invoiceId)
      .orderBy('at', descending: true)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) _fromDoc(d.id, d.data())]);

  @override
  Future<Result<void>> recordPayment({
    required String invoiceId,
    required String branchId,
    required int amountPaise,
    required PaymentMode mode,
    required String by,
    String? ref,
  }) async {
    if (amountPaise <= 0) {
      return Err(
        const ValidationFailure(
          ValidationReason.paymentExceedsBalance,
          'Payment amount must be positive',
        ),
      );
    }
    try {
      final invoiceRef = _invoice(invoiceId);
      final paymentRef = _payments.doc();
      final failure = await _firestore.runTransaction<Failure?>((tx) async {
        final snap = await tx.get(invoiceRef);
        final data = snap.data();
        if (!snap.exists || data == null) {
          return NotFoundFailure('Invoice $invoiceId not found');
        }
        final total = FirestoreConvert.toInt(data['totalPaise']);
        final paid = FirestoreConvert.toInt(data['amountPaidPaise']);
        final newPaid = paid + amountPaise;
        if (newPaid > total) {
          return const ValidationFailure(
            ValidationReason.paymentExceedsBalance,
            'Payment exceeds the outstanding balance',
          );
        }
        final status = newPaid >= total
            ? PaymentStatus.paid
            : (newPaid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid);
        tx
          ..update(invoiceRef, <String, dynamic>{
            'amountPaidPaise': newPaid,
            'paymentStatus': status.toWire,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(paymentRef, <String, dynamic>{
            'invoiceId': invoiceId,
            'branchId': branchId,
            'amountPaise': amountPaise,
            'mode': mode.toWire,
            if (ref != null) 'ref': ref,
            'at': FieldValue.serverTimestamp(),
            'by': by,
            'createdAt': FieldValue.serverTimestamp(),
          });
        return null;
      });
      if (failure != null) return Err(failure);
      await writeActivityLog(
        _firestore,
        actor: by,
        action: 'payment.record.${mode.toWire}',
        entity: Collections.payments,
        entityId: paymentRef.id,
        after: <String, dynamic>{
          'invoiceId': invoiceId,
          'amountPaise': amountPaise,
        },
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(_failureFor(e));
    }
  }

  Payment _fromDoc(String id, Map<String, dynamic> data) => Payment(
        id: id,
        invoiceId: FirestoreConvert.toStr(data['invoiceId']),
        amountPaise: FirestoreConvert.toInt(data['amountPaise']),
        mode: PaymentMode.fromWire(data['mode'] as String?) ?? PaymentMode.cash,
        branchId: FirestoreConvert.toStr(data['branchId']),
        ref: data['ref'] as String?,
        at: FirestoreConvert.toDateTime(data['at']),
        by: data['by'] as String?,
      );

  Failure _failureFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return PermissionFailure(error.message ?? error.code);
    }
    return UnexpectedFailure(error.toString());
  }
}
