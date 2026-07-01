import '../../../../core/errors/result.dart';
import '../../../customers/domain/repositories/customers_repository.dart';
import '../entities/job.dart';
import '../repositories/jobs_repository.dart';

/// Searches jobs across three axes — jobNo prefix, customer (name/phone), and
/// watch serial — then merges and de-duplicates the results.
///
/// Pure orchestration over the repository interfaces, so it has no Firebase
/// imports and is unit-testable with fakes. Returns the first [Err] encountered.
class SearchJobsService {
  /// Creates the service over the two repositories it fans out to.
  SearchJobsService({
    required JobsRepository jobs,
    required CustomersRepository customers,
  })  : _jobs = jobs,
        _customers = customers;

  final JobsRepository _jobs;
  final CustomersRepository _customers;

  /// Returns jobs in [branchId] matching [query] (jobNo / customer / serial).
  /// An empty [query] yields no results.
  Future<Result<List<Job>>> search(String branchId, String query) async {
    final term = query.trim();
    if (term.isEmpty) return const Ok(<Job>[]);

    // 1. Direct jobNo prefix.
    final byJobNo = await _jobs.searchJobsByJobNo(branchId, term);
    if (byJobNo.failureOrNull != null) return Err(byJobNo.failureOrNull!);

    // 2. Customers matching name/phone -> their jobs.
    final customers = await _customers.searchCustomers(branchId, term);
    if (customers.failureOrNull != null) return Err(customers.failureOrNull!);
    final byCustomer = await _jobs.jobsForCustomers(
      branchId,
      customers.valueOrNull!.map((c) => c.id).toList(),
    );
    if (byCustomer.failureOrNull != null) return Err(byCustomer.failureOrNull!);

    // 3. Watches matching serial -> their jobs.
    final watches = await _customers.searchWatchesBySerial(branchId, term);
    if (watches.failureOrNull != null) return Err(watches.failureOrNull!);
    final byWatch = await _jobs.jobsForWatches(
      branchId,
      watches.valueOrNull!.map((w) => w.id).toList(),
    );
    if (byWatch.failureOrNull != null) return Err(byWatch.failureOrNull!);

    // Merge + de-dupe by id, ordered by jobNo.
    final merged = <String, Job>{};
    for (final job in [
      ...byJobNo.valueOrNull!,
      ...byCustomer.valueOrNull!,
      ...byWatch.valueOrNull!,
    ]) {
      merged[job.id] = job;
    }
    final results = merged.values.toList()
      ..sort((a, b) => a.jobNo.compareTo(b.jobNo));
    return Ok(results);
  }
}
