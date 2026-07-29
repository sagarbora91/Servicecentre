import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/job_deep_link.dart';

void main() {
  group('job deep link', () {
    test('buildJobLink encodes the doc id', () {
      expect(buildJobLink('abc123'), 'servicecentre://job/abc123');
    });

    test('parseJobId round-trips a built link', () {
      expect(parseJobId(buildJobLink('abc123')), 'abc123');
    });

    test('parseJobId rejects other schemes, hosts, and garbage', () {
      expect(parseJobId('https://example.com/job/x'), isNull);
      expect(parseJobId('servicecentre://other/x'), isNull);
      expect(parseJobId('servicecentre://job/'), isNull);
      expect(parseJobId('random-code'), isNull);
    });

    test('jobIdFromScan returns the first valid id, skipping noise', () {
      expect(
        jobIdFromScan([null, 'random-code', buildJobLink('j9'), 'x']),
        'j9',
      );
    });

    test('jobIdFromScan returns null when nothing matches', () {
      expect(jobIdFromScan([null, 'random-code']), isNull);
      expect(jobIdFromScan(const <String?>[]), isNull);
    });
  });
}
