import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/data_import/domain/import_report.dart';
import 'package:service_centre_app/features/data_import/domain/part_import.dart';

void main() {
  group('parsePartsCsv', () {
    test('parses parts and converts rupees to paise', () {
      const csv =
          'reference,category,bin,onHand,reorderPoint,minLevel,cost,mrp,serviceOnly\n'
          'SR626,Battery,A1,10,2,1,15,40,no\n';

      final report = parsePartsCsv(csv);

      expect(report.errorCount, 0);
      final p = report.valid.single;
      expect(p.reference, 'SR626');
      expect(p.category, 'Battery');
      expect(p.binCode, 'A1');
      expect(p.onHand, 10);
      expect(p.reorderPoint, 2);
      expect(p.minLevel, 1);
      expect(p.costPaise, 1500);
      expect(p.mrpPaise, 4000);
      expect(p.serviceOnly, isFalse);
    });

    test('defaults numeric and optional columns when absent', () {
      const csv = 'reference\nSR626\n';

      final report = parsePartsCsv(csv);

      final p = report.valid.single;
      expect(p.onHand, 0);
      expect(p.reorderPoint, 0);
      expect(p.minLevel, 0);
      expect(p.costPaise, 0);
      expect(p.mrpPaise, 0);
      expect(p.category, '');
      expect(p.binCode, '');
      expect(p.size, isNull);
      expect(p.serviceOnly, isFalse);
    });

    test('flags an invalid number cell and skips the row', () {
      const csv = 'reference,onHand\nSR626,-3\n';

      final report = parsePartsCsv(csv);

      expect(report.okCount, 0);
      expect(report.errors.single.issue, ImportIssue.invalidNumber);
      expect(report.errors.single.line, 1);
    });

    test('flags invalid money', () {
      const csv = 'reference,cost\nSR626,abc\n';

      final report = parsePartsCsv(csv);

      expect(report.okCount, 0);
      expect(report.errors.single.issue, ImportIssue.invalidMoney);
    });

    test('flags a row missing its reference', () {
      const csv = 'reference,category\n,Battery\n';

      final report = parsePartsCsv(csv);

      expect(report.okCount, 0);
      expect(report.errors.single.issue, ImportIssue.missingReference);
    });

    test('a missing reference column fails the whole file', () {
      const csv = 'category,bin\nBattery,A1\n';

      final report = parsePartsCsv(csv);

      expect(report.okCount, 0);
      expect(report.errors.single.issue, ImportIssue.missingRequiredColumn);
      expect(report.errors.single.detail, 'reference');
    });
  });
}
