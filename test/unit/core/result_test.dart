import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/errors/failure.dart';
import 'package:service_centre_app/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value and reports success', () {
      const result = Ok<int>(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure and reports error', () {
      const failure = UnexpectedFailure('boom');
      const result = Err<int>(failure);
      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });

    test('switch exhaustively matches both variants', () {
      Result<String> classify({required bool ok}) =>
          ok ? const Ok('yes') : const Err(UnexpectedFailure('no'));

      final message = switch (classify(ok: true)) {
        Ok<String>(:final value) => value,
        Err<String>(:final failure) => failure.message,
      };
      expect(message, 'yes');
    });
  });
}
