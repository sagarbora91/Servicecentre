import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice.dart';
import 'package:service_centre_app/features/billing/domain/services/gst_calculator.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';

void main() {
  Invoice build({int taxPaise = 0, int paidPaise = 0}) => Invoice(
        id: 'i1',
        jobId: 'j1',
        number: 'INV-2607-0001',
        branchId: 'MAIN',
        lines: const [],
        taxablePaise: 100000,
        taxPaise: taxPaise,
        totalPaise: 100000 + taxPaise,
        amountPaidPaise: paidPaise,
        paymentStatus: PaymentStatus.unpaid,
      );

  test('defaults to an intra-state supply and zero paid', () {
    expect(build().place, GstPlace.intraState);
    expect(build().amountPaidPaise, 0);
  });

  test('hasTax reflects whether any GST was charged', () {
    expect(build(taxPaise: 0).hasTax, isFalse);
    expect(build(taxPaise: 18000).hasTax, isTrue);
  });

  test('balancePaise is total minus paid, never negative', () {
    expect(build().balancePaise, 100000);
    expect(build(paidPaise: 40000).balancePaise, 60000);
    expect(build(paidPaise: 100000).balancePaise, 0);
    // Defensive: an over-recorded paid amount clamps to zero.
    expect(build(paidPaise: 120000).balancePaise, 0);
  });
}
