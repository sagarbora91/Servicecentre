import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice_line.freezed.dart';

/// A single line on an invoice (`invoices/{id}.lines`, BUILD_BRIEF.md §5.1).
///
/// [ratePaise] is the GST-exclusive unit price in integer paise (BUILD_BRIEF
/// §4); [qty] the quantity; [gstPct] the combined GST rate as a whole
/// percentage (e.g. 18 for 18%, split CGST 9 / SGST 9 intra-state), or 0 when
/// GST does not apply (bill of supply). [hsn] is the HSN/SAC code (optional
/// until the owner is GST-registered). freezed value type; the Firestore
/// mapping lives in the `data` layer so `domain` stays Firebase-free.
@freezed
abstract class InvoiceLine with _$InvoiceLine {
  /// Creates an invoice line.
  const factory InvoiceLine({
    required String desc,
    required int qty,
    required int ratePaise,
    required int gstPct,
    String? hsn,
  }) = _InvoiceLine;

  const InvoiceLine._();

  /// The GST-exclusive taxable value of this line, in paise (`ratePaise * qty`).
  int get taxablePaise => ratePaise * qty;
}
