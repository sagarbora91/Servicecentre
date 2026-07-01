import '../../../../core/errors/result.dart';
import '../../../jobs/domain/entities/payment_status.dart';
import '../entities/invoice.dart';
import '../entities/invoice_line.dart';
import '../services/gst_calculator.dart';

/// Contract for reading and mutating [Invoice]s.
///
/// Lives in `domain` (no Firebase imports); the `data` implementation adapts
/// Cloud Firestore. Live reads expose a [Stream]; one-shot reads/writes return
/// a [Result] and never throw across layers.
abstract interface class InvoicesRepository {
  /// Streams the invoices for [jobId], newest first.
  Stream<List<Invoice>> watchInvoicesForJob(String jobId);

  /// Fetches an invoice by document [id] (`NotFoundFailure` if absent).
  Future<Result<Invoice>> getInvoice(String id);

  /// Raises an invoice for [jobId] from [lines]. The GST totals are computed
  /// from the lines via [GstCalculator] (per [place]), a unique number is
  /// allocated transactionally, and the invoice starts [PaymentStatus.unpaid].
  Future<Result<Invoice>> createInvoice({
    required String jobId,
    required String branchId,
    required List<InvoiceLine> lines,
    required String createdBy,
    GstPlace place,
  });

  /// Sets the payment status of invoice [id] (advanced by M7-D payments).
  Future<Result<void>> updatePaymentStatus(
    String id,
    PaymentStatus status,
    String by,
  );
}
