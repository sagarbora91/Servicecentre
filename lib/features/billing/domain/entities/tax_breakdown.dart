import 'package:freezed_annotation/freezed_annotation.dart';

part 'tax_breakdown.freezed.dart';

/// The GST breakdown of an invoice line or a whole invoice, all in integer
/// paise (BUILD_BRIEF.md §4).
///
/// For an intra-state supply the tax is split into [cgstPaise] + [sgstPaise]
/// (and [igstPaise] is 0); for an inter-state supply it is all [igstPaise]
/// (and CGST/SGST are 0). [taxPaise] is their sum and [totalPaise] is
/// [taxablePaise] + [taxPaise]. Computed by `GstCalculator`; never persisted on
/// its own (invoices persist `taxablePaise`/`taxPaise`/`totalPaise`).
@freezed
abstract class TaxBreakdown with _$TaxBreakdown {
  /// Creates a tax breakdown.
  const factory TaxBreakdown({
    required int taxablePaise,
    required int cgstPaise,
    required int sgstPaise,
    required int igstPaise,
    required int taxPaise,
    required int totalPaise,
  }) = _TaxBreakdown;

  const TaxBreakdown._();

  /// A zero breakdown for a given [taxablePaise] (no tax applied).
  factory TaxBreakdown.untaxed(int taxablePaise) => TaxBreakdown(
        taxablePaise: taxablePaise,
        cgstPaise: 0,
        sgstPaise: 0,
        igstPaise: 0,
        taxPaise: 0,
        totalPaise: taxablePaise,
      );
}
