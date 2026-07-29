import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../providers/auth_providers.dart';

/// Orchestrates the sign-in action and exposes its in-flight state, so the
/// login widget holds no business logic.
///
/// The async state is `void`: `loading` while a sign-in is running, `data`
/// otherwise. The failure (if any) is returned from [signIn] for the widget
/// to localize and show; it is not kept as error state, so the form stays
/// usable.
class SignInController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Attempts sign-in. Returns `null` on success or the [Failure] to display.
  Future<Failure?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue<void>.loading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithEmail(email: email, password: password);
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }
}

/// The sign-in controller provider.
final signInControllerProvider =
    AutoDisposeAsyncNotifierProvider<SignInController, void>(
  SignInController.new,
);
