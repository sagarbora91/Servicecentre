import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_providers.dart';
import '../providers/users_providers.dart';

/// Orchestrates the owner's staff-management writes and exposes their in-flight
/// state, so the admin widgets hold no business logic.
///
/// Mirrors [SignInController]: the async state is `void` (`loading` while a
/// write runs, `data` otherwise) and the [Failure] (if any) is returned for the
/// widget to localize, not kept as error state — so the form stays usable.
class ManageStaffController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// The acting user's uid, stamped into audit fields. Empty when the profile
  /// is somehow unavailable; the server rules remain the real guard.
  String get _actingUid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';

  /// Creates or updates a staff member. Returns `null` on success or the
  /// [Failure] to display.
  Future<Failure?> save(AppUser user) async {
    state = const AsyncValue<void>.loading();
    final result = await ref
        .read(usersRepositoryProvider)
        .upsertStaff(user, by: _actingUid);
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }

  /// Activates or deactivates a staff member. Returns `null` on success or the
  /// [Failure] to display.
  Future<Failure?> setActive(String uid, {required bool active}) async {
    state = const AsyncValue<void>.loading();
    final result = await ref
        .read(usersRepositoryProvider)
        .setActive(uid, active: active, by: _actingUid);
    state = const AsyncValue<void>.data(null);
    return result.failureOrNull;
  }
}

/// The staff-management controller provider.
final manageStaffControllerProvider =
    AutoDisposeAsyncNotifierProvider<ManageStaffController, void>(
  ManageStaffController.new,
);
