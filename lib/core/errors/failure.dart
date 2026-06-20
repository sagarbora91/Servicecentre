/// Domain-level failure types returned inside [Err] (see `result.dart`).
///
/// Failures are intentionally free of Firebase types so they can cross into
/// `domain`/`presentation`. The UI maps a failure's machine-readable reason to
/// a localized string; [message] is a non-localized developer fallback.
sealed class Failure {
  const Failure(this.message);

  /// Developer-facing, non-localized description. Not shown to end users.
  final String message;
}

/// Reasons an authentication operation can fail. The UI maps each to a
/// localized message.
enum AuthFailureReason {
  /// Email/password did not match an account.
  invalidCredentials,

  /// The account exists but has been disabled.
  userDisabled,

  /// The device is offline or the request timed out.
  network,

  /// Too many attempts; the account is temporarily throttled.
  tooManyRequests,

  /// An unclassified authentication error.
  unknown,
}

/// An authentication failure with a classified [reason].
final class AuthFailure extends Failure {
  /// Creates an authentication failure.
  const AuthFailure(this.reason, super.message);

  /// The classified reason, used by the UI to pick a localized message.
  final AuthFailureReason reason;
}

/// The signed-in user is not permitted to perform the action.
final class PermissionFailure extends Failure {
  /// Creates a permission failure.
  const PermissionFailure(super.message);
}

/// An unexpected or unclassified failure.
final class UnexpectedFailure extends Failure {
  /// Creates an unexpected failure.
  const UnexpectedFailure(super.message);
}
