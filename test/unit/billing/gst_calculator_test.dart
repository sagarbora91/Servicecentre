import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice_line.dart';
import 'package:service_centre_app/features/billing/domain/entities/tax_breakdown.dart';
import 'package:service_centre_app/features/billing/domain/services/gst_calculator.dart';

void main() {
  group('GstCalculator.taxOn', () {
    test('computes a whole-rupee tax exactly', () {
      // 18% of ₹1000.00 (100000 paise) = ₹180.00.
      expect(GstCalculator.taxOn(100000, 18), 18000);
      // 12% of ₹250.00 = ₹30.00.
      expect(GstCalculator.taxOn(25000, 12), 3000);
    });

    test('rounds half-up to the nearest paise', () {
      // 18% of ₹1.05 = 18.9 paise -> 19 paise.
      expect(GstCalculator.taxOn(105, 18), 19);
      // 18% of ₹0.25 = 4.5 paise -> 5 paise (half rounds up).
      expect(GstCalculator.taxOn(25, 18), 5);
    });

    test('is zero when the rate is zero', () {
      expect(GstCalculator.taxOn(999999, 0), 0);
    });
  });

  group('GstCalculator.lineBreakdown (intra-state, default)', () {
    test('splits tax evenly into CGST and SGST', () {
      final b = GstCalculator.lineBreakdown(taxablePaise: 100000, gstPct: 18);
      expect(b.taxPaise, 18000);
      expect(b.cgstPaise, 9000);
      expect(b.sgstPaise, 9000);
      expect(b.igstPaise, 0);
      expect(b.totalPaise, 118000);
    });

    test('puts an odd remaining paise on SGST so the halves sum to the tax', () {
      // 18% of ₹1.05 = 19 paise (odd): CGST 9 + SGST 10.
      final b = GstCalculator.lineBreakdown(taxablePaise: 105, gstPct: 18);
      expect(b.taxPaise, 19);
      expect(b.cgstPaise, 9);
      expect(b.sgstPaise, 10);
      expect(b.cgstPaise + b.sgstPaise, b.taxPaise);
    });

    test('a zero rate yields an untaxed line', () {
      final b = GstCalculator.lineBreakdown(taxablePaise: 50000, gstPct: 0);
      expect(b.taxPaise, 0);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
      expect(b.totalPaise, 50000);
    });
  });

  group('GstCalculator.lineBreakdown (inter-state)', () {
    test('puts all tax on IGST', () {
      final b = GstCalculator.lineBreakdown(
        taxablePaise: 100000,
        gstPct: 18,
        place: GstPlace.interState,
      );
      expect(b.igstPaise, 18000);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
      expect(b.taxPaise, 18000);
      expect(b.totalPaise, 118000);
    });
  });

  group('GstCalculator.invoiceBreakdown', () {
    test('sums per-line tax across mixed rates (intra-state)', () {
      const lines = [
        // ₹500.00 x 2 @ 18% -> taxable 100000, tax 18000
        InvoiceLine(desc: 'Service', qty: 2, ratePaise: 50000, gstPct: 18),
        // ₹250.00 x 1 @ 12% -> taxable 25000, tax 3000
        InvoiceLine(desc: 'Battery', qty: 1, ratePaise: 25000, gstPct: 12),
        // ₹100.00 x 1 @ 0% -> taxable 10000, tax 0 (exempt line)
        InvoiceLine(desc: 'Exempt', qty: 1, ratePaise: 10000, gstPct: 0),
      ];

      final b = GstCalculator.invoiceBreakdown(lines);

      expect(b.taxablePaise, 135000);
      expect(b.cgstPaise, 10500); // 9000 + 1500 + 0
      expect(b.sgstPaise, 10500);
      expect(b.igstPaise, 0);
      expect(b.taxPaise, 21000);
      expect(b.totalPaise, 156000);
    });

    test('an empty invoice is all zeros', () {
      final b = GstCalculator.invoiceBreakdown(const []);
      expect(b.taxablePaise, 0);
      expect(b.taxPaise, 0);
      expect(b.totalPaise, 0);
    });

    test('inter-state aggregates into IGST', () {
      const lines = [
        InvoiceLine(desc: 'Service', qty: 1, ratePaise: 100000, gstPct: 18),
      ];
      final b = GstCalculator.invoiceBreakdown(lines, place: GstPlace.interState);
      expect(b.igstPaise, 18000);
      expect(b.cgstPaise, 0);
      expect(b.sgstPaise, 0);
      expect(b.totalPaise, 118000);
    });
  });

  group('TaxBreakdown.untaxed', () {
    test('is a zero-tax breakdown whose total equals the taxable', () {
      final b = TaxBreakdown.untaxed(75000);
      expect(b.taxablePaise, 75000);
      expect(b.taxPaise, 0);
      expect(b.totalPaise, 75000);
    });
  });
}
