import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_outcome.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_part.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_qc.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status_change.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/warranty_type.dart';

Job _job({
  JobStatus status = JobStatus.received,
  PaymentStatus paymentStatus = PaymentStatus.unbilled,
  List<JobPart> partsUsed = const <JobPart>[],
  List<JobStatusChange> statusHistory = const <JobStatusChange>[],
}) =>
    Job(
      id: 'j1',
      jobNo: 'J-001',
      customerId: 'c1',
      status: status,
      fault: 'not running',
      workRequested: 'full service',
      tatTargetHrs: 48,
      dueAt: DateTime.utc(2026, 6, 25, 10),
      paymentStatus: paymentStatus,
      isRework: false,
      branchId: 'b1',
      partsUsed: partsUsed,
      statusHistory: statusHistory,
    );

void main() {
  final due = DateTime.utc(2026, 6, 25, 10);
  final at = DateTime.utc(2026, 6, 20, 9, 30);

  group('JobQc', () {
    test('isComplete is true only when every flag passes', () {
      const all = JobQc(
        timekeeping: true,
        gasket: true,
        glassClean: true,
        strap: true,
        crown: true,
      );

      expect(all.isComplete, isTrue);
    });

    test('isComplete is false when any flag is false', () {
      const qc = JobQc(
        timekeeping: true,
        gasket: true,
        glassClean: true,
        strap: true,
        crown: false,
      );

      expect(qc.isComplete, isFalse);
    });

    test('equality is value-based and copyWith replaces named flags', () {
      const a = JobQc(
        timekeeping: true,
        gasket: false,
        glassClean: true,
        strap: false,
        crown: true,
      );
      const same = JobQc(
        timekeeping: true,
        gasket: false,
        glassClean: true,
        strap: false,
        crown: true,
      );

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a.copyWith(crown: false).isComplete, isFalse);
    });
  });

  group('JobPart', () {
    test('holds its fields', () {
      const part = JobPart(partId: 'p1', qty: 2, ref: 'GASKET-30');

      expect(part.partId, 'p1');
      expect(part.qty, 2);
      expect(part.ref, 'GASKET-30');
    });

    test('equality is value-based and copyWith replaces named fields', () {
      const part = JobPart(partId: 'p9', qty: 3, ref: 'CROWN');
      const same = JobPart(partId: 'p9', qty: 3, ref: 'CROWN');

      expect(part, same);
      expect(part.hashCode, same.hashCode);
      expect(part.copyWith(qty: 5).qty, 5);
    });
  });

  group('JobStatusChange', () {
    test('holds status, timestamp, and uid', () {
      final change = JobStatusChange(
        status: JobStatus.inRepair,
        at: at,
        by: 'u1',
      );

      expect(change.status, JobStatus.inRepair);
      expect(change.at, at);
      expect(change.at.isUtc, isTrue);
      expect(change.by, 'u1');
    });

    test('equality is value-based', () {
      final a = JobStatusChange(status: JobStatus.ready, at: at, by: 'tech7');
      final same =
          JobStatusChange(status: JobStatus.ready, at: at, by: 'tech7');
      final different =
          JobStatusChange(status: JobStatus.qc, at: at, by: 'tech7');

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(different));
    });
  });

  group('Job', () {
    test('holds required fields and defaults optionals/collections', () {
      final job = _job();

      expect(job.id, 'j1');
      expect(job.jobNo, 'J-001');
      expect(job.customerId, 'c1');
      expect(job.status, JobStatus.received);
      expect(job.paymentStatus, PaymentStatus.unbilled);
      expect(job.dueAt, due);
      expect(job.isRework, isFalse);
      expect(job.branchId, 'b1');
      // Optionals default to null.
      expect(job.watchId, isNull);
      expect(job.sourceStore, isNull);
      expect(job.assignedTo, isNull);
      expect(job.qc, isNull);
      expect(job.outcome, isNull);
      expect(job.warrantyType, isNull);
      expect(job.parentJobId, isNull);
      expect(job.amountPaise, isNull);
      expect(job.createdAt, isNull);
      expect(job.createdBy, isNull);
      expect(job.updatedAt, isNull);
      // Collections default empty.
      expect(job.intakePhotos, isEmpty);
      expect(job.deliveryPhotos, isEmpty);
      expect(job.partsUsed, isEmpty);
      expect(job.statusHistory, isEmpty);
    });

    test('carries optional, nested, and audit fields when provided', () {
      const qc = JobQc(
        timekeeping: true,
        gasket: true,
        glassClean: true,
        strap: true,
        crown: true,
      );
      final job = _job(
        status: JobStatus.inRepair,
        paymentStatus: PaymentStatus.partial,
        partsUsed: const [
          JobPart(partId: 'p1', qty: 1, ref: 'BATT'),
          JobPart(partId: 'p2', qty: 2, ref: 'GASKET'),
        ],
        statusHistory: [
          JobStatusChange(status: JobStatus.received, at: at, by: 'u1'),
          JobStatusChange(
            status: JobStatus.inRepair,
            at: at.add(const Duration(hours: 1)),
            by: 'tech1',
          ),
        ],
      ).copyWith(
        watchId: 'w1',
        sourceStore: 'store-2',
        assignedTo: 'tech1',
        intakePhotos: const ['a.jpg', 'b.jpg'],
        deliveryPhotos: const ['d.jpg'],
        qc: qc,
        outcome: JobOutcome.repaired,
        warrantyType: WarrantyType.paid,
        parentJobId: 'j0',
        amountPaise: 125000,
        createdAt: at,
        createdBy: 'u1',
        updatedAt: at,
      );

      expect(job.status, JobStatus.inRepair);
      expect(job.paymentStatus, PaymentStatus.partial);
      expect(job.watchId, 'w1');
      expect(job.sourceStore, 'store-2');
      expect(job.assignedTo, 'tech1');
      expect(job.intakePhotos, ['a.jpg', 'b.jpg']);
      expect(job.deliveryPhotos, ['d.jpg']);
      expect(job.qc, isNotNull);
      expect(job.qc!.isComplete, isTrue);
      expect(job.partsUsed, hasLength(2));
      expect(
        job.partsUsed.first,
        const JobPart(partId: 'p1', qty: 1, ref: 'BATT'),
      );
      expect(job.outcome, JobOutcome.repaired);
      expect(job.warrantyType, WarrantyType.paid);
      expect(job.parentJobId, 'j0');
      expect(job.amountPaise, 125000);
      expect(job.statusHistory, hasLength(2));
      expect(job.statusHistory.last.status, JobStatus.inRepair);
      expect(job.statusHistory.last.by, 'tech1');
      expect(job.createdAt, at);
      expect(job.createdBy, 'u1');
      expect(job.updatedAt, at);
    });

    test('keeps money as integer paise and dates as UTC', () {
      final job = _job().copyWith(amountPaise: 125000);

      expect(job.amountPaise, 125000);
      expect(job.dueAt.isUtc, isTrue);
    });

    test('equality is value-based across nested collections', () {
      final a = _job(
        partsUsed: const [JobPart(partId: 'p1', qty: 1, ref: 'X')],
      );
      final same = _job(
        partsUsed: const [JobPart(partId: 'p1', qty: 1, ref: 'X')],
      );

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a.copyWith(status: JobStatus.qc), isNot(a));
    });

    test('copyWith replaces only the named fields', () {
      final job = _job();
      final moved = job.copyWith(
        status: JobStatus.qc,
        paymentStatus: PaymentStatus.paid,
      );

      expect(moved.status, JobStatus.qc);
      expect(moved.paymentStatus, PaymentStatus.paid);
      // Untouched fields are preserved.
      expect(moved.id, 'j1');
      expect(moved.jobNo, 'J-001');
      expect(moved.branchId, 'b1');
    });
  });
}
