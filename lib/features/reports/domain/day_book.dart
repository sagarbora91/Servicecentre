import '../../billing/domain/entities/payment.dart';
import '../../billing/domain/entities/payment_mode.dart';

/// A day-book reconciliation: collections grouped by [PaymentMode] plus the
/// grand total and count, all in integer paise (BUILD_BRIEF.md §4). Pure value
/// computed from a set of [Payment]s (BUILD_BRIEF §12 M7 "day-book balances").
class DayBook {
  /// Creates a day-book from its parts. Prefer [DayBook.fromPayments].
  const DayBook({
    required this.byMode,
    required this.totalPaise,
    required this.count,
  });

  /// Reconciles [payments] into per-mode totals, a grand total and a count. The
  /// grand total always equals the sum of the per-mode totals (it balances).
  factory DayBook.fromPayments(Iterable<Payment> payments) {
    final byMode = <PaymentMode, int>{};
    var total = 0;
    var count = 0;
    for (final p in payments) {
      byMode[p.mode] = (byMode[p.mode] ?? 0) + p.amountPaise;
      total += p.amountPaise;
      count++;
    }
    return DayBook(byMode: byMode, totalPaise: total, count: count);
  }

  /// Collections per payment mode, in paise (absent modes read 0 via
  /// [amountFor]).
  final Map<PaymentMode, int> byMode;

  /// The grand total collected, in paise.
  final int totalPaise;

  /// The number of payments reconciled.
  final int count;

  /// The amount collected via [mode], in paise (0 if none).
  int amountFor(PaymentMode mode) => byMode[mode] ?? 0;
}
