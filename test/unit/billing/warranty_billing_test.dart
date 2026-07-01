import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/services/warranty_billing.dart';
import 'package:service_centre_app/features/jobs/domain/entities/warranty_type.dart';

void main() {
  group('isBillableUnderWarranty', () {
    test('an ordinary or paid job is billable', () {
      expect(isBillableUnderWarranty(null), isTrue);
      expect(isBillableUnderWarranty(WarrantyType.paid), isTrue);
    });

    test('in-warranty and goodwill jobs are not billable', () {
      expect(isBillableUnderWarranty(WarrantyType.inWarranty), isFalse);
      expect(isBillableUnderWarranty(WarrantyType.goodwill), isFalse);
    });
  });
}
