/// Firestore collection names, kept in one place so paths are not stringly
/// duplicated across the data layer (BUILD_BRIEF.md §5.1).
abstract final class Collections {
  const Collections._();

  /// `users/{uid}` — staff accounts and their roles.
  static const String users = 'users';

  /// `customers/{id}` — customer records.
  static const String customers = 'customers';

  /// `watches/{id}` — customer watches under service.
  static const String watches = 'watches';

  /// `jobs/{id}` — service jobs.
  static const String jobs = 'jobs';

  /// `parts/{id}` — inventory parts.
  static const String parts = 'parts';

  /// `stockMovements/{id}` — append-only stock ledger.
  static const String stockMovements = 'stockMovements';

  /// `activityLog/{id}` — append-only audit trail for every write.
  static const String activityLog = 'activityLog';

  /// `counters/{branchId_YYMM}` — transactional sequence counters backing
  /// per-branch, per-month job numbers (see `JobNoAllocator`).
  static const String counters = 'counters';

  /// `estimates/{id}` — customer quotes for a job (M7).
  static const String estimates = 'estimates';

  /// `invoices/{id}` — GST/plain invoices raised for a job (M7).
  static const String invoices = 'invoices';

  /// `payments/{id}` — payments recorded against an invoice (M7).
  static const String payments = 'payments';

  /// `settings/{branchId}` — per-branch configuration (tax, rate card,
  /// templates). Backs GST-configurable billing (M7).
  static const String settings = 'settings';

  /// `suppliers/{id}` — parts suppliers (M10).
  static const String suppliers = 'suppliers';

  /// `orders/{id}` — purchase orders with goods-receipt (M10).
  static const String orders = 'orders';

  /// `stockTakes/{id}` — physical stock-count reconciliations (M10).
  static const String stockTakes = 'stockTakes';

  /// `warranties/{id}` — warranty records for jobs (M10).
  static const String warranties = 'warranties';

  /// `feedback/{id}` — customer feedback on delivered jobs (M11).
  static const String feedback = 'feedback';
}
