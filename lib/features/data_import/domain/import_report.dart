/// Why a CSV import row (or the file as a whole) was rejected. The UI maps each
/// to a localized message; this stays machine-readable.
enum ImportIssue {
  /// A required column is absent from the header (a file-level problem).
  missingRequiredColumn,

  /// A customer row has no name.
  missingName,

  /// A customer row has no phone.
  missingPhone,

  /// A customer phone repeats an earlier row in the same file.
  duplicatePhoneInFile,

  /// A part row has no reference.
  missingReference,

  /// A numeric cell (on-hand / reorder / min level) is not a whole number ≥ 0.
  invalidNumber,

  /// A money cell (cost / MRP) is not a valid amount ≥ 0.
  invalidMoney,
}

/// One problem found while parsing a CSV, tied to a source [line] (1-based data
/// row; `0` means a file-level/header problem). [detail] carries context such as
/// the missing column name or the offending value (not localized).
class ImportError {
  /// Creates an import error.
  const ImportError({required this.line, required this.issue, this.detail});

  /// 1-based source data-row number, or `0` for a file-level problem.
  final int line;

  /// The machine-readable reason.
  final ImportIssue issue;

  /// Optional context (column name, offending value), for display only.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is ImportError &&
      other.line == line &&
      other.issue == issue &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(line, issue, detail);

  @override
  String toString() => 'ImportError(line: $line, issue: $issue, detail: $detail)';
}

/// The result of parsing a CSV: the [valid] rows ready to write and the [errors]
/// for the rows (or file) that failed validation.
class ImportReport<T> {
  /// Creates an import report.
  const ImportReport({required this.valid, required this.errors});

  /// Rows that parsed and validated cleanly.
  final List<T> valid;

  /// Problems found, in source order.
  final List<ImportError> errors;

  /// Number of importable rows.
  int get okCount => valid.length;

  /// Number of rejected rows / file-level problems.
  int get errorCount => errors.length;

  /// Whether any problems were found.
  bool get hasErrors => errors.isNotEmpty;
}
