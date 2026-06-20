import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/firebase/converters.dart';

void main() {
  group('FirestoreConvert', () {
    test('toDateTime converts a Timestamp to a UTC DateTime', () {
      final dt = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final result = FirestoreConvert.toDateTime(Timestamp.fromDate(dt));
      expect(result, dt);
      expect(result!.isUtc, isTrue);
      expect(FirestoreConvert.toDateTime(null), isNull);
      expect(FirestoreConvert.toDateTime('not a timestamp'), isNull);
    });

    test('toTimestamp stores a DateTime as UTC', () {
      final dt = DateTime.utc(2026, 6, 21, 10, 30);
      final ts = FirestoreConvert.toTimestamp(dt);
      expect(ts, isNotNull);
      expect(ts!.toDate().toUtc(), dt);
      expect(FirestoreConvert.toTimestamp(null), isNull);
    });

    test('toInt reads ints and nums, else falls back', () {
      expect(FirestoreConvert.toInt(5), 5);
      expect(FirestoreConvert.toInt(5.9), 5);
      expect(FirestoreConvert.toInt(null), 0);
      expect(FirestoreConvert.toInt('x', fallback: -1), -1);
    });

    test('toBool / toStr / toStringList read with fallbacks', () {
      expect(FirestoreConvert.toBool(true), isTrue);
      expect(FirestoreConvert.toBool(null), isFalse);
      expect(FirestoreConvert.toStr('a'), 'a');
      expect(FirestoreConvert.toStr(null, fallback: 'd'), 'd');
      expect(FirestoreConvert.toStringList(<dynamic>['a', 1, 'b']), ['a', 'b']);
      expect(FirestoreConvert.toStringList(null), isEmpty);
    });
  });
}
