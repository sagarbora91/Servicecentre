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
