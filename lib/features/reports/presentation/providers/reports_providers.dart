import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../billing/domain/entities/payment.dart';
import '../../../billing/presentation/providers/billing_providers.dart';

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
