import '../../jobs/domain/entities/job.dart';
import '../../jobs/domain/entities/job_status.dart';

/// Operational KPIs for a date range, computed from jobs (BUILD_BRIEF.md §12 M9:
/// "TAT / first-time-fix / comeback / uncollected match seeded data"). Pure
/// value; money is integer paise (BUILD_BRIEF §4).
class KpiSummary {
  /// Creates a KPI summary. Prefer [KpiSummary.compute].
  const KpiSummary({
    required this.jobsReceived,
    required this.jobsDelivered,
    required this.avgTatHours,
    required this.firstTimeFixPct,
    required this.comebacks,
    required this.uncollected,
    required this.revenuePaise,
  });

  /// Computes the KPIs for the half-open range [from, to) from [jobs].
  ///
  /// - **received**: jobs created in the range.
  /// - **delivered**: jobs whose `delivered` status change falls in the range;
  ///   their TAT (hours from `createdAt` to that delivery) drives [avgTatHours].
  /// - **first-time-fix %**: share of delivered jobs that are not rework.
  /// - **comebacks**: rework jobs created in the range.
  /// - **uncollected**: jobs currently `ready` and past due as of [now]
  ///   (a snapshot, independent of the range).
  /// - **revenue**: passed in from invoices ([revenuePaise]); 0 if unknown.
  factory KpiSummary.compute({
    required List<Job> jobs,
    required DateTime from,
    required DateTime to,
    required DateTime now,
    int revenuePaise = 0,
  }) {
    var received = 0;
    var delivered = 0;
    var firstTimeFix = 0;
    var comebacks = 0;
    var uncollected = 0;
    var tatHoursTotal = 0.0;

    for (final job in jobs) {
      final createdAt = job.createdAt;
      if (createdAt != null && _inRange(createdAt, from, to)) {
        received += 1;
        if (job.isRework) comebacks += 1;
      }

      final deliveredAt = _deliveredAtIn(job, from, to);
      if (deliveredAt != null) {
        delivered += 1;
        if (!job.isRework) firstTimeFix += 1;
        if (createdAt != null) {
          tatHoursTotal +=
              deliveredAt.difference(createdAt).inMinutes / 60.0;
        }
      }

      if (job.status == JobStatus.ready && job.dueAt.isBefore(now)) {
        uncollected += 1;
      }
    }

    return KpiSummary(
      jobsReceived: received,
      jobsDelivered: delivered,
      avgTatHours: delivered == 0 ? 0 : tatHoursTotal / delivered,
      firstTimeFixPct: delivered == 0 ? 0 : (firstTimeFix / delivered) * 100,
      comebacks: comebacks,
      uncollected: uncollected,
      revenuePaise: revenuePaise,
    );
  }

  /// Jobs received (created) in the range.
  final int jobsReceived;

  /// Jobs delivered in the range.
  final int jobsDelivered;

  /// Average turnaround time in hours for jobs delivered in the range.
  final double avgTatHours;

  /// Percentage of delivered jobs fixed first time (not rework), 0–100.
  final double firstTimeFixPct;

  /// Rework jobs ("comebacks") created in the range.
  final int comebacks;

  /// Jobs currently ready but not collected past their due date.
  final int uncollected;

  /// Revenue invoiced in the range, in paise.
  final int revenuePaise;

  /// The timestamp of a `delivered` status change within [from, to), or `null`
  /// if the job was not delivered in the range.
  static DateTime? _deliveredAtIn(Job job, DateTime from, DateTime to) {
    for (final change in job.statusHistory) {
      if (change.status == JobStatus.delivered &&
          _inRange(change.at, from, to)) {
        return change.at;
      }
    }
    return null;
  }

  static bool _inRange(DateTime t, DateTime from, DateTime to) =>
      !t.isBefore(from) && t.isBefore(to);
}
