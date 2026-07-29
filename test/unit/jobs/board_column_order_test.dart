import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';

void main() {
  group('kBoardColumnOrder', () {
    test('contains every JobStatus exactly once', () {
      expect(kBoardColumnOrder.length, JobStatus.values.length);
      expect(kBoardColumnOrder.toSet(), JobStatus.values.toSet());
    });

    test('runs in lifecycle order, received first and returned last', () {
      expect(kBoardColumnOrder.first, JobStatus.received);
      expect(kBoardColumnOrder.last, JobStatus.returned);
      // The intake column precedes the closed columns.
      expect(
        kBoardColumnOrder.indexOf(JobStatus.received),
        lessThan(kBoardColumnOrder.indexOf(JobStatus.delivered)),
      );
    });
  });
}
