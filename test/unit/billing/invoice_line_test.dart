import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/invoice_line.dart';

void main() {
  group('InvoiceLine.taxablePaise', () {
    test('is unit rate times quantity', () {
      const line =
          InvoiceLine(desc: 'Service', qty: 3, ratePaise: 50000, gstPct: 18);
      expect(line.taxablePaise, 150000);
    });

    test('is the rate when quantity is one', () {
      const line =
          InvoiceLine(desc: 'Battery', qty: 1, ratePaise: 25000, gstPct: 12);
      expect(line.taxablePaise, 25000);
    });
  });
}
