import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';

void main() {
  group('allowedTransitions', () {
    test('received moves to diagnosed or returned', () {
      expect(
        allowedTransitions(JobStatus.received),
        {JobStatus.diagnosed, JobStatus.returned},
      );
    });

    test('ready moves to delivered or returned', () {
      expect(
        allowedTransitions(JobStatus.ready),
        {JobStatus.delivered, JobStatus.returned},
      );
    });

    test('qc can bounce back to inRepair', () {
      expect(allowedTransitions(JobStatus.qc), contains(JobStatus.inRepair));
    });

    test('delivered and returned are terminal', () {
      expect(allowedTransitions(JobStatus.delivered), isEmpty);
      expect(allowedTransitions(JobStatus.returned), isEmpty);
    });

    test('no status transitions to itself', () {
      for (final status in JobStatus.values) {
        expect(allowedTransitions(status), isNot(contains(status)));
      }
    });
  });
}
