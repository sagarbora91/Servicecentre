import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/entities/delivery_gate.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_qc.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';

const _completeQc = JobQc(
  timekeeping: true,
  gasket: true,
  glassClean: true,
  strap: true,
  crown: true,
);

const _incompleteQc = JobQc(
  timekeeping: true,
  gasket: true,
  glassClean: false,
  strap: true,
  crown: true,
);

Job _job({JobQc? qc, List<String> deliveryPhotos = const []}) => Job(
      id: 'j1',
      jobNo: '2606-0001',
      customerId: 'c1',
      status: JobStatus.ready,
      fault: 'fault',
      workRequested: 'work',
      tatTargetHrs: 24,
      dueAt: DateTime.utc(2030),
      paymentStatus: PaymentStatus.unbilled,
      isRework: false,
      branchId: 'b1',
      qc: qc,
      deliveryPhotos: deliveryPhotos,
    );

void main() {
  group('deliveryGateResult', () {
    test('qcMissing when there is no QC map', () {
      final job = _job(deliveryPhotos: const ['p.jpg']);
      expect(deliveryGateResult(job), DeliveryGate.qcMissing);
      expect(job.canDeliver, isFalse);
    });

    test('qcIncomplete when a QC check has not passed', () {
      final job = _job(qc: _incompleteQc, deliveryPhotos: const ['p.jpg']);
      expect(deliveryGateResult(job), DeliveryGate.qcIncomplete);
      expect(job.canDeliver, isFalse);
    });

    test('noDeliveryPhoto when QC is complete but no photo exists', () {
      final job = _job(qc: _completeQc);
      expect(deliveryGateResult(job), DeliveryGate.noDeliveryPhoto);
      expect(job.canDeliver, isFalse);
    });

    test('ready when QC is complete and there is a delivery photo', () {
      final job = _job(qc: _completeQc, deliveryPhotos: const ['p.jpg']);
      expect(deliveryGateResult(job), DeliveryGate.ready);
      expect(job.canDeliver, isTrue);
    });
  });
}
