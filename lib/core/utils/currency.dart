// Money formatting helpers. Amounts are stored as integer **paise**
// (BUILD_BRIEF.md §4); this is the single place that turns them into a
// display-only `₹` string. Never feed the result back into calculations.

/// Formats [paise] as an Indian-rupee string with two decimal places: `250000`
/// becomes `₹2500.00`, `5` becomes `₹0.05`. Negative amounts keep the sign
/// before the symbol (`-₹5.00`). Integer math throughout, so there is no
/// floating-point rounding error.
String formatPaise(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final paisePart = (abs % 100).toString().padLeft(2, '0');
  return '$sign₹$rupees.$paisePart';
}

/// Parses a user-entered non-negative rupee amount into integer paise using
/// string math (no floating point), so paise are exact. Accepts `"2500"`,
/// `"2500.5"`, `"2500.50"` (up to two decimals); returns `null` for anything
/// else. `"2500.5"` → `250050`, `"0.05"` → `5`.
int? parseRupeesToPaise(String input) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  var paise = int.parse(match.group(1)!) * 100;
  final frac = match.group(2);
  if (frac != null) paise += int.parse(frac.padRight(2, '0'));
  return paise;
}

/// Formats [paise] as a plain, symbol-less two-decimal rupee string for
/// spreadsheets/CSV (`250050` → `"2500.50"`, `-500` → `"-5.00"`). String math,
/// so no floating-point error.
String rupeesPlain(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}
