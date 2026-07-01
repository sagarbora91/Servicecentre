import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One `label: value` line on a job slip.
class JobSlipRow {
  /// Creates a slip row.
  const JobSlipRow(this.label, this.value);

  /// The field label (already localized).
  final String label;

  /// The field value.
  final String value;
}

/// The (already-localized) content of a printable job slip. Kept as plain
/// strings so the PDF builder is pure and unit-testable without a
/// `BuildContext`; the job-detail screen builds this from `AppLocalizations`.
class JobSlipData {
  /// Creates job-slip content.
  const JobSlipData({
    required this.title,
    required this.jobNo,
    required this.rows,
    required this.partsLabel,
    required this.parts,
    required this.footer,
  });

  /// Small heading above the job number (e.g. "Job slip").
  final String title;

  /// The prominent job number.
  final String jobNo;

  /// The detail lines (customer, fault, work, due).
  final List<JobSlipRow> rows;

  /// Heading for the parts list (e.g. "Parts used").
  final String partsLabel;

  /// Parts-used lines (e.g. "BATT x2"); empty hides the section.
  final List<String> parts;

  /// Footer text (e.g. the centre name).
  final String footer;
}

/// Renders [data] into a small (A6) job-slip PDF and returns its bytes. Pure
/// Dart (the `pdf` package builds in memory); printing/sharing is done by the
/// caller via the `printing` package.
Future<Uint8List> buildJobSlipPdf(JobSlipData data) {
  final doc = pw.Document()
    ..addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.title,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Text(
              data.jobNo,
              style: const pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Divider(),
            for (final row in data.rows)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 72,
                    child: pw.Text(
                      row.label,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row.value,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            if (data.parts.isNotEmpty) pw.Divider(),
            if (data.parts.isNotEmpty)
              pw.Text(
                data.partsLabel,
                style: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            for (final part in data.parts)
              pw.Text(part, style: const pw.TextStyle(fontSize: 9)),
            pw.Divider(),
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
