import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../jobs/domain/entities/payment_status.dart';
import '../services/gst_calculator.dart';
import 'invoice_line.dart';

part 'invoice.freezed.dart';

/// A raised invoice for a job (`invoices/{id}`, BUILD_BRIEF.md §5.1).
///
/// Holds the billed [lines] plus the computed GST totals ([taxablePaise],
/// [taxPaise], [totalPaise]) and the [paymentStatus] (which payments in M7-D
/// advance unpaid → partial → paid). [place] records whether GST was split
/// CGST/SGST (intra-state) or charged as IGST. All money is integer paise
/// (BUILD_BRIEF §4). freezed value type; Firestore mapping lives in `data`.
@freezed
abstract class Invoice with _$Invoice {
  /// Creates an invoice.
  const factory Invoice({
    required String id,
    required String jobId,
    required String number,
    required String branchId,
    required List<InvoiceLine> lines,
    required int taxablePaise,
    required int taxPaise,
    required int totalPaise,
    required PaymentStatus paymentStatus,
    @Default(GstPlace.intraState) GstPlace place,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _Invoice;

  const Invoice._();

  /// Whether this invoice carries any GST (a tax invoice vs a bill of supply).
  bool get hasTax => taxPaise > 0;
}
