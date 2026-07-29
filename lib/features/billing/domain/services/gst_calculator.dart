import '../entities/invoice_line.dart';
import '../entities/tax_breakdown.dart';

/// Where a supply is made, which decides how GST is split.
enum GstPlace {
  /// Supplier and customer in the same state: tax splits into CGST + SGST.
  /// The default for a single-branch service centre.
  intraState,

  /// Supplier and customer in different states: tax is a single IGST amount.
  interState,
}

/// Pure GST math (BUILD_BRIEF.md §7 "invoice tax split correct").
///
/// All amounts are integer paise (BUILD_BRIEF §4) — no floating point, so there
/// is never a rounding error. [gstPct] is the combined rate as a whole
/// percentage (e.g. 18); tax is rounded half-up to the nearest paise. For an
/// intra-state supply the per-line tax is split CGST/SGST as evenly as possible
/// (any odd paise goes to SGST) so CGST + SGST always equals the line tax.
/// A [gstPct] of 0 yields an untaxed line (bill of supply).
abstract final class GstCalculator {
  const GstCalculator._();

  /// The GST on [taxablePaise] at [gstPct]%, rounded half-up to the nearest
  /// paise. Both inputs must be non-negative.
  static int taxOn(int taxablePaise, int gstPct) =>
      (taxablePaise * gstPct + 50) ~/ 100;

  /// The [TaxBreakdown] for one line of [taxablePaise] at [gstPct]%, split
  /// according to [place].
  static TaxBreakdown lineBreakdown({
    required int taxablePaise,
    required int gstPct,
    GstPlace place = GstPlace.intraState,
  }) {
    final tax = taxOn(taxablePaise, gstPct);
    if (place == GstPlace.interState) {
      return TaxBreakdown(
        taxablePaise: taxablePaise,
        cgstPaise: 0,
        sgstPaise: 0,
        igstPaise: tax,
        taxPaise: tax,
        totalPaise: taxablePaise + tax,
      );
    }
    final cgst = tax ~/ 2;
    final sgst = tax - cgst; // odd paise goes to SGST so cgst + sgst == tax
    return TaxBreakdown(
      taxablePaise: taxablePaise,
      cgstPaise: cgst,
      sgstPaise: sgst,
      igstPaise: 0,
      taxPaise: tax,
      totalPaise: taxablePaise + tax,
    );
  }

  /// The aggregate [TaxBreakdown] for [lines]. Tax is computed per line (lines
  /// may carry different rates) and then summed, which is how a GST invoice is
  /// totalled.
  static TaxBreakdown invoiceBreakdown(
    Iterable<InvoiceLine> lines, {
    GstPlace place = GstPlace.intraState,
  }) {
    var taxable = 0;
    var cgst = 0;
    var sgst = 0;
    var igst = 0;
    for (final line in lines) {
      final b = lineBreakdown(
        taxablePaise: line.taxablePaise,
        gstPct: line.gstPct,
        place: place,
      );
      taxable += b.taxablePaise;
      cgst += b.cgstPaise;
      sgst += b.sgstPaise;
      igst += b.igstPaise;
    }
    final tax = cgst + sgst + igst;
    return TaxBreakdown(
      taxablePaise: taxable,
      cgstPaise: cgst,
      sgstPaise: sgst,
      igstPaise: igst,
      taxPaise: tax,
      totalPaise: taxable + tax,
    );
  }
}
