import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice.dart';
import 'package:service_centre_app/features/billing/domain/services/gst_calculator.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';

void main() {
  Invoice build({int taxPaise = 0}) => Invoice(
        id: 'i1',
        jobId: 'j1',
        number: 'INV-2607-0001',
        branchId: 'MAIN',
        lines: const [],
        taxablePaise: 100000,
        taxPaise: taxPaise,
        totalPaise: 100000 + taxPaise,
        paymentStatus: PaymentStatus.unpaid,
      );

  test('defaults to an intra-state supply', () {
    expect(build().place, GstPlace.intraState);
  });

  test('hasTax reflects whether any GST was charged', () {
    expect(build(taxPaise: 0).hasTax, isFalse);
    expect(build(taxPaise: 18000).hasTax, isTrue);
  });
}
