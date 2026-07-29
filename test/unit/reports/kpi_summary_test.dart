import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status_change.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';
import 'package:service_centre_app/features/reports/domain/kpi_summary.dart';

Job _job({
  required String id,
  required JobStatus status,
  required DateTime createdAt,
  required DateTime dueAt,
  bool isRework = false,
  DateTime? deliveredAt,
}) =>
    Job(
      id: id,
      jobNo: id,
      customerId: 'c1',
      status: status,
      fault: 'f',
      workRequested: 'w',
      tatTargetHrs: 24,
      dueAt: dueAt,
      paymentStatus: PaymentStatus.unbilled,
      isRework: isRework,
      branchId: 'b1',
      createdAt: createdAt,
      statusHistory: [
        JobStatusChange(status: JobStatus.received, at: createdAt, by: 'u'),
        if (deliveredAt != null)
          JobStatusChange(status: JobStatus.delivered, at: deliveredAt, by: 'u'),
      ],
    );

void main() {
  final from = DateTime.utc(2026, 7, 1);
  final to = DateTime.utc(2026, 7, 2);
  final now = DateTime.utc(2026, 7, 5);

  test('computes received/delivered/TAT/first-fix/comebacks/uncollected', () {
    final jobs = [
      // A: received + delivered in range, 6h TAT, first-time fix.
      _job(
        id: 'A',
        status: JobStatus.delivered,
        createdAt: DateTime.utc(2026, 7, 1, 9),
        dueAt: DateTime.utc(2026, 7, 2),
        deliveredAt: DateTime.utc(2026, 7, 1, 15),
      ),
      // B: received + delivered in range, 10h TAT, but a rework (comeback).
      _job(
        id: 'B',
        status: JobStatus.delivered,
        createdAt: DateTime.utc(2026, 7, 1, 10),
        dueAt: DateTime.utc(2026, 7, 2),
        isRework: true,
        deliveredAt: DateTime.utc(2026, 7, 1, 20),
      ),
      // C: created before the range, ready and past due -> uncollected only.
      _job(
        id: 'C',
        status: JobStatus.ready,
        createdAt: DateTime.utc(2026, 6, 30),
        dueAt: DateTime.utc(2026, 7, 4),
      ),
      // D: received in range, still in repair -> not delivered/uncollected.
      _job(
        id: 'D',
        status: JobStatus.inRepair,
        createdAt: DateTime.utc(2026, 7, 1, 8),
        dueAt: DateTime.utc(2026, 7, 10),
      ),
    ];

    final kpi = KpiSummary.compute(
      jobs: jobs,
      from: from,
      to: to,
      now: now,
      revenuePaise: 250000,
    );

    expect(kpi.jobsReceived, 3); // A, B, D
    expect(kpi.jobsDelivered, 2); // A, B
    expect(kpi.avgTatHours, closeTo(8, 0.001)); // (6 + 10) / 2
    expect(kpi.firstTimeFixPct, closeTo(50, 0.001)); // A fixed first time of 2
    expect(kpi.comebacks, 1); // B
    expect(kpi.uncollected, 1); // C
    expect(kpi.revenuePaise, 250000);
  });

  test('is all-zero for no jobs (no divide-by-zero)', () {
    final kpi = KpiSummary.compute(jobs: const [], from: from, to: to, now: now);
    expect(kpi.jobsReceived, 0);
    expect(kpi.jobsDelivered, 0);
    expect(kpi.avgTatHours, 0);
    expect(kpi.firstTimeFixPct, 0);
    expect(kpi.uncollected, 0);
  });
}
