import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/data_import/domain/import_report.dart';

void main() {
  group('ImportError', () {
    test('value equality, hashCode, and toString', () {
      const a = ImportError(line: 1, issue: ImportIssue.missingName);
      const b = ImportError(line: 1, issue: ImportIssue.missingName);
      const c = ImportError(line: 2, issue: ImportIssue.missingName);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.toString(), contains('missingName'));
    });
  });

  group('ImportReport', () {
    test('exposes counts and hasErrors', () {
      const clean = ImportReport<int>(valid: [1, 2], errors: []);
      expect(clean.okCount, 2);
      expect(clean.errorCount, 0);
      expect(clean.hasErrors, isFalse);

      const withError = ImportReport<int>(
        valid: [],
        errors: [
          ImportError(line: 0, issue: ImportIssue.missingRequiredColumn),
        ],
      );
      expect(withError.hasErrors, isTrue);
      expect(withError.errorCount, 1);
    });
  });
}
