import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../billing/domain/entities/invoice.dart';
import '../../../billing/domain/entities/payment.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../jobs/presentation/providers/jobs_providers.dart';
import '../../domain/kpi_summary.dart';

/// A branch-scoped date range for a report query. Records give it value
/// equality, so the [paymentsInRangeProvider] family caches per range.
typedef PaymentRange = ({String branchId, DateTime from, DateTime to});

/// Fetches the payments for a branch within a half-open date range, oldest
/// first. Throws (surfacing as `AsyncValue.error`) if the query fails.
final paymentsInRangeProvider =
    FutureProvider.autoDispose.family<List<Payment>, PaymentRange>(
  (ref, range) async {
    final result = await ref
        .read(paymentsRepositoryProvider)
        .paymentsInRange(range.branchId, range.from, range.to);
    final failure = result.failureOrNull;
    if (failure != null) throw Exception(failure.message);
    return result.valueOrNull ?? const [];
  },
);

/// Computes the [KpiSummary] for a branch/date range from its jobs and invoice
/// revenue. Throws (surfacing as `AsyncValue.error`) if either query fails.
final kpiSummaryProvider =
    FutureProvider.autoDispose.family<KpiSummary, PaymentRange>(
  (ref, range) async {
    final jobsResult = await ref
        .read(jobsRepositoryProvider)
        .jobsInRange(range.branchId, range.from, range.to);
    if (jobsResult.failureOrNull != null) {
      throw Exception(jobsResult.failureOrNull!.message);
    }
    final invoicesResult = await ref
        .read(invoicesRepositoryProvider)
        .invoicesInRange(range.branchId, range.from, range.to);
    if (invoicesResult.failureOrNull != null) {
      throw Exception(invoicesResult.failureOrNull!.message);
    }
    var revenue = 0;
    for (final inv in invoicesResult.valueOrNull ?? const <Invoice>[]) {
      revenue += inv.totalPaise;
    }
    return KpiSummary.compute(
      jobs: jobsResult.valueOrNull ?? const [],
      from: range.from,
      to: range.to,
      now: range.to,
      revenuePaise: revenue,
    );
  },
);
