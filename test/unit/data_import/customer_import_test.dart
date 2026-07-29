import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/data_import/domain/customer_import.dart';
import 'package:service_centre_app/features/data_import/domain/import_report.dart';

void main() {
  group('parseCustomersCsv', () {
    test('parses valid rows with optional columns', () {
      const csv = 'name,phone,email,address,consent\n'
          'Asha,111,asha@x.com,Pune,yes\n'
          'Bhau,222,,,no\n';

      final report = parseCustomersCsv(csv);

      expect(report.errorCount, 0);
      expect(report.okCount, 2);
      expect(report.valid[0].name, 'Asha');
      expect(report.valid[0].email, 'asha@x.com');
      expect(report.valid[0].consentWhatsApp, isTrue);
      expect(report.valid[1].email, isNull);
      expect(report.valid[1].consentWhatsApp, isFalse);
    });

    test('header order, casing, and spacing do not matter', () {
      const csv = 'Phone , Full Name\n111,Asha\n';

      final report = parseCustomersCsv(csv);

      expect(report.okCount, 1);
      expect(report.valid.single.name, 'Asha');
      expect(report.valid.single.phone, '111');
    });

    test('flags missing name and missing phone per row', () {
      const csv = 'name,phone\n,111\nBhau,\n';

      final report = parseCustomersCsv(csv);

      expect(report.okCount, 0);
      expect(report.errors, const [
        ImportError(line: 1, issue: ImportIssue.missingName),
        ImportError(line: 2, issue: ImportIssue.missingPhone),
      ]);
    });

    test('flags a phone duplicated within the file', () {
      const csv = 'name,phone\nAsha,111\nBhau,111\n';

      final report = parseCustomersCsv(csv);

      expect(report.okCount, 1);
      expect(report.errors.single.issue, ImportIssue.duplicatePhoneInFile);
      expect(report.errors.single.line, 2);
      expect(report.errors.single.detail, '111');
    });

    test('a missing required column fails the whole file', () {
      const csv = 'name,email\nAsha,asha@x.com\n';

      final report = parseCustomersCsv(csv);

      expect(report.okCount, 0);
      expect(
        report.errors.single,
        const ImportError(
          line: 0,
          issue: ImportIssue.missingRequiredColumn,
          detail: 'phone',
        ),
      );
    });

    test('an empty file reports both required columns missing', () {
      final report = parseCustomersCsv('');

      expect(report.okCount, 0);
      expect(report.errorCount, 2);
    });

    test('skips blank spacer rows', () {
      const csv = 'name,phone\nAsha,111\n\nBhau,222\n';

      final report = parseCustomersCsv(csv);

      expect(report.okCount, 2);
      expect(report.errorCount, 0);
    });

    test('imports a 50-row file (acceptance: 50-row CSV)', () {
      final buffer = StringBuffer('name,phone\n');
      for (var i = 0; i < 50; i++) {
        buffer.writeln('Cust $i,90000$i');
      }

      final report = parseCustomersCsv(buffer.toString());

      expect(report.okCount, 50);
      expect(report.errorCount, 0);
    });
  });
}
