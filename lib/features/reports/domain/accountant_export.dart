import 'package:csv/csv.dart';

import '../../billing/domain/entities/payment.dart';

/// Column headers for the accountant payments export, in order.
const accountantCsvHeader = <String>[
  'Date (UTC)',
  'Invoice',
  'Mode',
  'Amount (INR)',
  'Reference',
];

/// Builds an accountant-ready CSV of [payments] (BUILD_BRIEF.md §12 M7
/// "accountant CSV export ... opens in Excel"). Pure: money is rendered from
/// integer paise to a plain two-decimal rupee string with string math (no
/// floating point), and CSV quoting/escaping is handled by the `csv` package.
String buildPaymentsCsv(Iterable<Payment> payments) {
  final rows = <List<String>>[
    accountantCsvHeader,
    for (final p in payments)
      <String>[
        p.at?.toUtc().toIso8601String() ?? '',
        p.invoiceId,
        p.mode.toWire,
        _rupees(p.amountPaise),
        p.ref ?? '',
      ],
  ];
  return const ListToCsvConverter().convert(rows);
}

/// `250050` → `"2500.50"` (plain, symbol-less, two decimals) for spreadsheets.
String _rupees(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}
