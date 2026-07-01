import 'package:csv/csv.dart';

import '../../../core/utils/currency.dart';
import '../../billing/domain/entities/invoice.dart';
import '../../billing/domain/services/gst_calculator.dart';
import 'kpi_summary.dart';

/// Builds a KPI summary CSV (metric, value) for the dashboard export
/// (BUILD_BRIEF §12 M9 "export opens in Excel"). Pure; money is a plain
/// two-decimal rupee string.
String buildKpiCsv(KpiSummary kpi) {
  final rows = <List<String>>[
    ["Metric", "Value"],
    ["Received", "${kpi.jobsReceived}"],
    ["Delivered", "${kpi.jobsDelivered}"],
    ["Avg TAT (h)", kpi.avgTatHours.toStringAsFixed(1)],
    ["First-time fix %", kpi.firstTimeFixPct.toStringAsFixed(0)],
    ["Comebacks", "${kpi.comebacks}"],
    ["Uncollected", "${kpi.uncollected}"],
    ["Revenue (INR)", rupeesPlain(kpi.revenuePaise)],
  ];
  return const ListToCsvConverter().convert(rows);
}

/// Column headers for the GST report, in order.
const gstReportHeader = <String>[
  'Invoice',
  'Taxable (INR)',
  'CGST (INR)',
  'SGST (INR)',
  'IGST (INR)',
  'Total (INR)',
];

/// Builds a GST report CSV — one row per invoice with the CGST/SGST/IGST split
/// recomputed from its lines (BUILD_BRIEF §12 M9 "GST report"). Pure.
String buildGstReportCsv(Iterable<Invoice> invoices) {
  final rows = <List<String>>[
    gstReportHeader,
    for (final inv in invoices) _gstRow(inv),
  ];
  return const ListToCsvConverter().convert(rows);
}

List<String> _gstRow(Invoice inv) {
  final b = GstCalculator.invoiceBreakdown(inv.lines, place: inv.place);
  return <String>[
    inv.number,
    rupeesPlain(b.taxablePaise),
    rupeesPlain(b.cgstPaise),
    rupeesPlain(b.sgstPaise),
    rupeesPlain(b.igstPaise),
    rupeesPlain(inv.totalPaise),
  ];
}
