import 'failure.dart';

/// Outcome of an operation that can fail: either [Ok] with a value or [Err]
/// carrying a [Failure].
///
/// Repositories return `Result<T>` instead of throwing across layers (see
/// BUILD_BRIEF.md §4). The presentation layer pattern-matches and maps a
/// [Failure] to a localized message.
sealed class Result<T> {
  const Result();

  /// Whether this result is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Whether this result is an [Err].
  bool get isErr => this is Err<T>;

  /// The value if [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// The failure if [Err], otherwise `null`.
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };
}

/// A successful [Result] carrying a [value].
final class Ok<T> extends Result<T> {
  /// Creates a successful result.
  const Ok(this.value);

  /// The success value.
  final T value;
}

/// A failed [Result] carrying a [failure].
final class Err<T> extends Result<T> {
  /// Creates a failed result.
  const Err(this.failure);

  /// The reason the operation failed.
  final Failure failure;
}
