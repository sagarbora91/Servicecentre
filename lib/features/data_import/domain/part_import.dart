import 'package:freezed_annotation/freezed_annotation.dart';

import 'csv_table.dart';
import 'import_report.dart';
import 'value_parsers.dart';

part 'part_import.freezed.dart';

/// A part parsed from an import CSV, ready to be written via the inventory
/// repository. Money is integer **paise** (converted from rupees in the CSV).
@freezed
abstract class PartImportRow with _$PartImportRow {
  /// Creates a parsed part row.
  const factory PartImportRow({
    required String category,
    required String reference,
    required String binCode,
    required int onHand,
    required int reorderPoint,
    required int minLevel,
    required int costPaise,
    required int mrpPaise,
    @Default(false) bool serviceOnly,
    String? size,
  }) = _PartImportRow;

  const PartImportRow._();
}

/// Parses a parts CSV into validated [PartImportRow]s plus per-row errors.
/// Header names are case/space/underscore-insensitive.
///
/// Columns (required *): **reference***, `category`, `bin`, `size`, `onHand`,
/// `reorderPoint`, `minLevel`, `cost` (₹), `mrp` (₹), `serviceOnly`. Numeric
/// columns default to 0 when absent; a present-but-invalid number/money cell
/// rejects that row. `cost`/`mrp` are read in rupees and stored as paise.
ImportReport<PartImportRow> parsePartsCsv(String csv) {
  final table = CsvTable.parse(csv);
  final refCol = table.column(['reference', 'ref', 'partref', 'partreference']);
  if (refCol == null) {
    return const ImportReport<PartImportRow>(
      valid: [],
      errors: [
        ImportError(
          line: 0,
          issue: ImportIssue.missingRequiredColumn,
          detail: 'reference',
        ),
      ],
    );
  }

  final categoryCol = table.column(['category', 'cat']);
  final binCol = table.column(['bin', 'bincode']);
  final sizeCol = table.column(['size']);
  final onHandCol = table.column(['onhand', 'qty', 'quantity', 'stock']);
  final reorderCol = table.column(['reorderpoint', 'reorder']);
  final minLevelCol = table.column(['minlevel', 'min']);
  final costCol = table.column(['cost', 'costprice']);
  final mrpCol = table.column(['mrp', 'price', 'sellingprice']);
  final serviceOnlyCol = table.column(['serviceonly', 'service']);

  final valid = <PartImportRow>[];
  final errors = <ImportError>[];
  for (var i = 0; i < table.rows.length; i++) {
    final row = table.rows[i];
    if (table.isBlank(row)) continue;
    final line = i + 1;
    final reference = table.value(row, refCol);
    if (reference == null) {
      errors.add(ImportError(line: line, issue: ImportIssue.missingReference));
      continue;
    }
    final onHand = parseCount(table.value(row, onHandCol));
    final reorder = parseCount(table.value(row, reorderCol));
    final minLevel = parseCount(table.value(row, minLevelCol));
    if (onHand == null || reorder == null || minLevel == null) {
      errors.add(ImportError(line: line, issue: ImportIssue.invalidNumber));
      continue;
    }
    final costPaise = parseMoneyToPaise(table.value(row, costCol));
    final mrpPaise = parseMoneyToPaise(table.value(row, mrpCol));
    if (costPaise == null || mrpPaise == null) {
      errors.add(ImportError(line: line, issue: ImportIssue.invalidMoney));
      continue;
    }
    valid.add(
      PartImportRow(
        category: table.value(row, categoryCol) ?? '',
        reference: reference,
        binCode: table.value(row, binCol) ?? '',
        onHand: onHand,
        reorderPoint: reorder,
        minLevel: minLevel,
        costPaise: costPaise,
        mrpPaise: mrpPaise,
        serviceOnly: parseFlag(table.value(row, serviceOnlyCol)),
        size: table.value(row, sizeCol),
      ),
    );
  }
  return ImportReport<PartImportRow>(valid: valid, errors: errors);
}
