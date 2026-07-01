import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch_settings.freezed.dart';

/// Per-branch configuration (`settings/{branchId}`, BUILD_BRIEF.md §5.1).
///
/// For M7 this carries the billing/GST configuration: [gstEnabled] gates
/// whether invoices are full tax invoices (GSTIN + HSN + CGST/SGST) or plain
/// bills of supply, and [gstin]/[legalName]/[address] populate the invoice
/// header. The owner is not yet GST-registered, so [gstEnabled] defaults to
/// false and [gstin] stays null until registration (m7-decisions). freezed
/// value type; Firestore mapping lives in `data`.
@freezed
abstract class BranchSettings with _$BranchSettings {
  /// Creates branch settings.
  const factory BranchSettings({
    required String branchId,
    @Default(false) bool gstEnabled,
    String? gstin,
    String? legalName,
    String? address,
  }) = _BranchSettings;

  const BranchSettings._();

  /// Defaults for a branch with no `settings/{branchId}` document yet: GST off,
  /// no GSTIN (a plain bill of supply).
  factory BranchSettings.defaults(String branchId) =>
      BranchSettings(branchId: branchId);
}
