import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_providers.dart';

/// Holds the job-search results as [AsyncValue] state (unlike the void write
/// controllers): empty initially, `loading` while a search runs, then the
/// matches or an error.
class JobSearchController extends AutoDisposeAsyncNotifier<List<Job>> {
  @override
  FutureOr<List<Job>> build() => const <Job>[];

  /// Runs a search for [query] in the signed-in user's branch. An empty query
  /// (or no branch) resets to no results.
  Future<void> search(String query) async {
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null || query.trim().isEmpty) {
      state = const AsyncValue<List<Job>>.data(<Job>[]);
      return;
    }
    state = const AsyncValue<List<Job>>.loading();
    final result =
        await ref.read(searchJobsServiceProvider).search(branchId, query);
    final jobs = result.valueOrNull;
    state = jobs != null
        ? AsyncValue<List<Job>>.data(jobs)
        : AsyncValue<List<Job>>.error(
            result.failureOrNull!,
            StackTrace.current,
          );
  }
}

/// The job-search controller provider.
final jobSearchControllerProvider =
    AutoDisposeAsyncNotifierProvider<JobSearchController, List<Job>>(
  JobSearchController.new,
);
