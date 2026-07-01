import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/settings/domain/entities/branch_settings.dart';

void main() {
  group('BranchSettings.defaults', () {
    test('is GST off with no GSTIN for the given branch', () {
      final s = BranchSettings.defaults('MAIN');
      expect(s.branchId, 'MAIN');
      expect(s.gstEnabled, isFalse);
      expect(s.gstin, isNull);
      expect(s.legalName, isNull);
    });
  });
}
