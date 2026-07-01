import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One line on an invoice PDF. All money fields are pre-formatted `₹` strings
/// (the caller formats via `formatPaise`) so this builder stays pure.
class InvoicePdfLine {
  /// Creates an invoice PDF line.
  const InvoicePdfLine({
    required this.desc,
    required this.qty,
    required this.rate,
    required this.amount,
    this.hsn,
    this.gstPct,
  });

  /// Line description.
  final String desc;

  /// HSN/SAC code (shown only on tax invoices).
  final String? hsn;

  /// Quantity.
  final int qty;

  /// Unit rate (`₹` string).
  final String rate;

  /// GST rate percent (shown only on tax invoices).
  final int? gstPct;

  /// Line taxable amount (`₹` string).
  final String amount;
}

/// The (already-localized, already-`₹`-formatted) content of an invoice PDF.
/// Kept as plain strings so the builder is pure and unit-testable without a
/// `BuildContext`; the invoice screen builds this from the [Invoice],
/// [BranchSettings] and `AppLocalizations`.
class InvoicePdfData {
  /// Creates invoice PDF content.
  const InvoicePdfData({
    required this.title,
    required this.number,
    required this.sellerName,
    required this.customerName,
    required this.columnDesc,
    required this.columnQty,
    required this.columnRate,
    required this.columnAmount,
    required this.lines,
    required this.taxableLabel,
    required this.taxable,
    required this.totalLabel,
    required this.total,
    required this.footer,
    required this.showTax,
    this.sellerGstin,
    this.sellerAddress,
    this.columnHsn,
    this.columnGst,
    this.cgstLabel,
    this.cgst,
    this.sgstLabel,
    this.sgst,
    this.igstLabel,
    this.igst,
  });

  /// Heading (e.g. "Tax Invoice" or "Bill of Supply").
  final String title;

  /// The invoice number.
  final String number;

  /// Seller (branch) legal name.
  final String sellerName;

  /// Seller GSTIN (tax invoices only).
  final String? sellerGstin;

  /// Seller address (optional).
  final String? sellerAddress;

  /// Customer name.
  final String customerName;

  /// Column headers.
  final String columnDesc;
  final String? columnHsn;
  final String columnQty;
  final String columnRate;
  final String? columnGst;
  final String columnAmount;

  /// The invoice lines.
  final List<InvoicePdfLine> lines;

  /// Whether to render HSN/GST columns and the CGST/SGST/IGST rows.
  final bool showTax;

  /// Totals block (labels + `₹` values).
  final String taxableLabel;
  final String taxable;
  final String? cgstLabel;
  final String? cgst;
  final String? sgstLabel;
  final String? sgst;
  final String? igstLabel;
  final String? igst;
  final String totalLabel;
  final String total;

  /// Footer text.
  final String footer;
}

/// Renders [data] into an A5 invoice PDF and returns its bytes. Pure Dart (the
/// `pdf` package builds in memory); printing/sharing is done by the caller via
/// the `printing` package. Devanagari (mr/hi) needs an embedded font (M11); the
/// default font is Latin-only.
Future<Uint8List> buildInvoicePdf(InvoicePdfData data) {
  final doc = pw.Document()
    ..addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.title,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              data.number,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Text(data.sellerName, style: const pw.TextStyle(fontSize: 10)),
            if (data.sellerAddress != null)
              pw.Text(
                data.sellerAddress!,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            if (data.showTax && data.sellerGstin != null)
              pw.Text(
                'GSTIN: ${data.sellerGstin}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            pw.SizedBox(height: 4),
            pw.Text(
              data.customerName,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
            pw.Divider(),
            _table(data),
            pw.Divider(),
            _totals(data),
            pw.Spacer(),
            pw.Text(
              data.footer,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  return doc.save();
}

pw.Widget _table(InvoicePdfData data) {
  final headers = <String>[
    data.columnDesc,
    if (data.showTax && data.columnHsn != null) data.columnHsn!,
    data.columnQty,
    data.columnRate,
    if (data.showTax && data.columnGst != null) data.columnGst!,
    data.columnAmount,
  ];
  final rows = <List<String>>[
    for (final line in data.lines)
      <String>[
        line.desc,
        if (data.showTax && data.columnHsn != null) line.hsn ?? '',
        '${line.qty}',
        line.rate,
        if (data.showTax && data.columnGst != null)
          line.gstPct == null ? '' : '${line.gstPct}%',
        line.amount,
      ],
  ];
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _totals(InvoicePdfData data) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _totalRow(data.taxableLabel, data.taxable),
        if (data.showTax && data.cgst != null && data.cgstLabel != null)
          _totalRow(data.cgstLabel!, data.cgst!),
        if (data.showTax && data.sgst != null && data.sgstLabel != null)
          _totalRow(data.sgstLabel!, data.sgst!),
        if (data.showTax && data.igst != null && data.igstLabel != null)
          _totalRow(data.igstLabel!, data.igst!),
        _totalRow(data.totalLabel, data.total, bold: true),
      ],
    );

pw.Widget _totalRow(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(
    fontSize: bold ? 11 : 9,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label, style: style),
        pw.SizedBox(width: 12),
        pw.SizedBox(width: 70, child: pw.Text(value, style: style)),
      ],
    ),
  );
}
