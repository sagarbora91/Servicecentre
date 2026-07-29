import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore <-> domain field conversion helpers, used by `data`-layer
/// repositories so `domain` models stay free of Firebase types.
///
/// Dates are stored UTC as [Timestamp] and surfaced as UTC [DateTime]; money is
/// stored as integer paise (BUILD_BRIEF §4).
abstract final class FirestoreConvert {
  const FirestoreConvert._();

  /// [Timestamp] -> UTC [DateTime], or `null` if [value] is not a Timestamp.
  static DateTime? toDateTime(Object? value) =>
      value is Timestamp ? value.toDate().toUtc() : null;

  /// UTC [DateTime] -> [Timestamp], or `null`.
  static Timestamp? toTimestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value.toUtc());

  /// Reads an int (or num) field, defaulting to [fallback].
  static int toInt(Object? value, {int fallback = 0}) => switch (value) {
        final int v => v,
        final num v => v.toInt(),
        _ => fallback,
      };

  /// Reads a bool field, defaulting to [fallback].
  static bool toBool(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;

  /// Reads a String field, defaulting to [fallback].
  static String toStr(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  /// Reads a `List<String>` field, ignoring non-string elements.
  static List<String> toStringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
