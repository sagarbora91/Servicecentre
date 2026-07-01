import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/presentation/invoice_pdf.dart';

void main() {
  group('buildInvoicePdf', () {
    const lines = [
      InvoicePdfLine(
        desc: 'Movement service',
        qty: 1,
        rate: '₹2500.00',
        amount: '₹2500.00',
        hsn: '998721',
        gstPct: 18,
      ),
    ];

    test('produces a non-empty PDF with the %PDF header (bill of supply)',
        () async {
      const data = InvoicePdfData(
        title: 'Bill of Supply',
        number: 'INV-2607-0001',
        sellerName: 'Service Centre',
        customerName: 'Asha',
        columnDesc: 'Item',
        columnQty: 'Qty',
        columnRate: 'Rate',
        columnAmount: 'Amount',
        lines: lines,
        taxableLabel: 'Subtotal',
        taxable: '₹2500.00',
        totalLabel: 'Total',
        total: '₹2500.00',
        footer: 'Thank you',
        showTax: false,
      );

      final bytes = await buildInvoicePdf(data);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('builds a tax invoice with GST columns and CGST/SGST rows', () async {
      const data = InvoicePdfData(
        title: 'Tax Invoice',
        number: 'INV-2607-0002',
        sellerName: 'Service Centre',
        sellerGstin: '27ABCDE1234F1Z5',
        sellerAddress: 'Main Road',
        customerName: 'Asha',
        columnDesc: 'Item',
        columnHsn: 'HSN',
        columnQty: 'Qty',
        columnRate: 'Rate',
        columnGst: 'GST%',
        columnAmount: 'Amount',
        lines: lines,
        taxableLabel: 'Taxable',
        taxable: '₹2500.00',
        cgstLabel: 'CGST',
        cgst: '₹225.00',
        sgstLabel: 'SGST',
        sgst: '₹225.00',
        totalLabel: 'Total',
        total: '₹2950.00',
        footer: 'Thank you',
        showTax: true,
      );

      final bytes = await buildInvoicePdf(data);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
