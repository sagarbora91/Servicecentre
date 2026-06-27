import 'package:csv/csv.dart';

/// A parsed CSV with a header row, used by the import parsers. Columns are
/// looked up by *normalized* header name (lower-cased, spaces/underscores
/// removed) so column order and minor header spelling don't matter, and cells
/// are read as trimmed strings (empty → `null`).
///
/// Pure Dart (no Firebase): the `csv` package only transforms text.
class CsvTable {
  const CsvTable._(this._headerIndex, this.rows);

  final Map<String, int> _headerIndex;

  /// The data rows (header excluded), each a list of raw string cells.
  final List<List<String>> rows;

  /// Parses [input] into a [CsvTable]. Tolerates `\r\n`/`\r` line endings and a
  /// trailing newline. An empty input yields an empty table.
  static CsvTable parse(String input) {
    final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final raw = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
        .convert(normalized);
    if (raw.isEmpty) return const CsvTable._(<String, int>{}, <List<String>>[]);

    final index = <String, int>{};
    final header = raw.first;
    for (var i = 0; i < header.length; i++) {
      final key = _normalize(header[i].toString());
      if (key.isNotEmpty) index.putIfAbsent(key, () => i);
    }

    final rows = <List<String>>[
      for (var r = 1; r < raw.length; r++)
        [for (final cell in raw[r]) cell.toString()],
    ];
    return CsvTable._(index, rows);
  }

  static String _normalize(String header) =>
      header.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');

  /// The index of the first header matching any of [candidates] (already
  /// normalized), or `null` if none is present.
  int? column(List<String> candidates) {
    for (final candidate in candidates) {
      final i = _headerIndex[candidate];
      if (i != null) return i;
    }
    return null;
  }

  /// The trimmed value of [row] at column [col], or `null` when the column is
  /// absent, out of range, or the cell is blank.
  String? value(List<String> row, int? col) {
    if (col == null || col >= row.length) return null;
    final v = row[col].trim();
    return v.isEmpty ? null : v;
  }

  /// Whether every cell in [row] is blank (a spacer line to skip).
  bool isBlank(List<String> row) => row.every((cell) => cell.trim().isEmpty);
}
