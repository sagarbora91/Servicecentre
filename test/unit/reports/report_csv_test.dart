import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice_line.dart';
import 'package:service_centre_app/features/billing/domain/services/gst_calculator.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';
import 'package:service_centre_app/features/reports/domain/kpi_summary.dart';
import 'package:service_centre_app/features/reports/domain/report_csv.dart';

List<String> _lines(String csv) =>
    csv.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();

void main() {
  group('buildKpiCsv', () {
    test('writes metric/value rows with a plain rupee revenue', () {
      const kpi = KpiSummary(
        jobsReceived: 3,
        jobsDelivered: 2,
        avgTatHours: 8,
        firstTimeFixPct: 50,
        comebacks: 1,
        uncollected: 1,
        revenuePaise: 250000,
      );

      final csv = buildKpiCsv(kpi);
      expect(_lines(csv).first, contains('Metric'));
      expect(csv, contains('Received'));
      expect(csv, contains('2500.00'));
    });
  });

  group('buildGstReportCsv', () {
    test('writes a header and one row per invoice with the CGST/SGST split', () {
      const invoice = Invoice(
        id: 'i1',
        jobId: 'j1',
        number: 'INV-2607-0001',
        branchId: 'MAIN',
        lines: const [
          InvoiceLine(desc: 'Service', qty: 1, ratePaise: 100000, gstPct: 18),
        ],
        taxablePaise: 100000,
        taxPaise: 18000,
        totalPaise: 118000,
        paymentStatus: PaymentStatus.unpaid,
        place: GstPlace.intraState,
      );

      final csv = buildGstReportCsv([invoice]);
      final lines = _lines(csv);
      expect(lines, hasLength(2));
      expect(lines.first, contains('CGST (INR)'));
      // 18% of ₹1000 -> CGST ₹90 + SGST ₹90.
      expect(csv, contains('INV-2607-0001'));
      expect(csv, contains('90.00'));
      expect(csv, contains('1180.00'));
    });

    test('is header-only for no invoices', () {
      final lines = _lines(buildGstReportCsv(const []));
      expect(lines, hasLength(1));
    });
  });
}
