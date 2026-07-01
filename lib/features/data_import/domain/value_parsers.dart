// Shared cell parsers for the CSV import. Each treats an absent cell (null) as
// the sensible default and signals a *present-but-invalid* cell with null so the
// caller can raise a per-row error.

/// Parses a boolean-ish cell: `true`/`yes`/`y`/`1` (case-insensitive) → `true`;
/// anything else, including `null`, → `false`.
bool parseFlag(String? raw) {
  if (raw == null) return false;
  final v = raw.toLowerCase();
  return v == 'true' || v == 'yes' || v == 'y' || v == '1';
}

/// Parses a non-negative whole-number cell. Absent → `0`; a valid integer ≥ 0 →
/// its value; present-but-invalid (non-integer or negative) → `null`.
int? parseCount(String? raw) {
  if (raw == null) return 0;
  final n = int.tryParse(raw);
  return (n == null || n < 0) ? null : n;
}

/// Parses a money cell given in **rupees** into integer **paise**. Absent → `0`;
/// valid (`250`, `250.50`, `₹1,250.00`) → paise; present-but-invalid → `null`.
int? parseMoneyToPaise(String? raw) {
  if (raw == null) return 0;
  final cleaned = raw.replaceAll(RegExp(r'[₹,\s]'), '');
  final amount = double.tryParse(cleaned);
  if (amount == null || amount < 0) return null;
  return (amount * 100).round();
}
