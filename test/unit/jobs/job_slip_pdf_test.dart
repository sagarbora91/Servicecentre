import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/presentation/job_slip_pdf.dart';

void main() {
  group('buildJobSlipPdf', () {
    test('produces a non-empty PDF with the %PDF header', () async {
      const data = JobSlipData(
        title: 'Job slip',
        jobNo: '2606-0001',
        rows: [
          JobSlipRow('Customer', 'Asha'),
          JobSlipRow('Fault', 'Not ticking'),
        ],
        partsLabel: 'Parts used',
        parts: ['BATT x2'],
        footer: 'Service Centre',
      );

      final bytes = await buildJobSlipPdf(data);

      expect(bytes, isNotEmpty);
      // Every PDF file starts with the "%PDF" magic header.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('builds when there are no parts', () async {
      const data = JobSlipData(
        title: 'Job slip',
        jobNo: 'X-1',
        rows: [JobSlipRow('Customer', 'A')],
        partsLabel: 'Parts',
        parts: [],
        footer: 'F',
      );

      final bytes = await buildJobSlipPdf(data);

      expect(bytes, isNotEmpty);
    });
  });
}
