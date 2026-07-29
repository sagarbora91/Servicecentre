import '../../../jobs/domain/entities/warranty_type.dart';

/// Whether a job with warranty coverage [type] should be billed the customer
/// (BUILD_BRIEF.md §12 M10 "warranty type drives billing").
///
/// - `null` (no warranty set) → billable (an ordinary paid job).
/// - [WarrantyType.paid] → billable.
/// - [WarrantyType.inWarranty] → **not** billable (covered under warranty).
/// - [WarrantyType.goodwill] → **not** billable (free of charge).
bool isBillableUnderWarranty(WarrantyType? type) =>
    type == null || type == WarrantyType.paid;
