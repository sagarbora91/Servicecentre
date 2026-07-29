import 'package:freezed_annotation/freezed_annotation.dart';

import 'csv_table.dart';
import 'import_report.dart';
import 'value_parsers.dart';

part 'customer_import.freezed.dart';

/// A customer parsed from an import CSV, ready to be written via the customers
/// repository. freezed value type (equality/`copyWith` generated).
@freezed
abstract class CustomerImportRow with _$CustomerImportRow {
  /// Creates a parsed customer row.
  const factory CustomerImportRow({
    required String name,
    required String phone,
    String? email,
    String? address,
    @Default(false) bool consentWhatsApp,
  }) = _CustomerImportRow;

  const CustomerImportRow._();
}

/// Parses a customers CSV into validated [CustomerImportRow]s plus per-row
/// errors. Header names are case/space/underscore-insensitive.
///
/// Columns (required *): **name***, **phone***, `email`, `address`,
/// `consent` (WhatsApp: yes/no/true/false). A missing required column makes the
/// whole file fail (one file-level error per missing column). Within the file,
/// a phone that repeats an earlier row is rejected as a duplicate; de-dupe
/// against existing customers happens at write time (repository `ConflictFailure`).
ImportReport<CustomerImportRow> parseCustomersCsv(String csv) {
  final table = CsvTable.parse(csv);
  final nameCol = table.column(['name', 'customername', 'fullname']);
  final phoneCol = table.column(['phone', 'phonenumber', 'mobile', 'contact']);

  final missing = <ImportError>[
    if (nameCol == null)
      const ImportError(
        line: 0,
        issue: ImportIssue.missingRequiredColumn,
        detail: 'name',
      ),
    if (phoneCol == null)
      const ImportError(
        line: 0,
        issue: ImportIssue.missingRequiredColumn,
        detail: 'phone',
      ),
  ];
  if (missing.isNotEmpty) {
    return ImportReport<CustomerImportRow>(valid: const [], errors: missing);
  }

  final emailCol = table.column(['email', 'emailid']);
  final addressCol = table.column(['address']);
  final consentCol = table.column(
    ['consent', 'whatsapp', 'consentwhatsapp', 'whatsappconsent'],
  );

  final valid = <CustomerImportRow>[];
  final errors = <ImportError>[];
  final seenPhones = <String>{};
  for (var i = 0; i < table.rows.length; i++) {
    final row = table.rows[i];
    if (table.isBlank(row)) continue;
    final line = i + 1;
    final name = table.value(row, nameCol);
    final phone = table.value(row, phoneCol);
    if (name == null) {
      errors.add(ImportError(line: line, issue: ImportIssue.missingName));
      continue;
    }
    if (phone == null) {
      errors.add(ImportError(line: line, issue: ImportIssue.missingPhone));
      continue;
    }
    if (!seenPhones.add(phone)) {
      errors.add(
        ImportError(
          line: line,
          issue: ImportIssue.duplicatePhoneInFile,
          detail: phone,
        ),
      );
      continue;
    }
    valid.add(
      CustomerImportRow(
        name: name,
        phone: phone,
        email: table.value(row, emailCol),
        address: table.value(row, addressCol),
        consentWhatsApp: parseFlag(table.value(row, consentCol)),
      ),
    );
  }
  return ImportReport<CustomerImportRow>(valid: valid, errors: errors);
}
