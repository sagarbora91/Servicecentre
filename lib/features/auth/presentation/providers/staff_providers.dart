import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import 'auth_providers.dart';
import 'users_providers.dart';

/// The signed-in user's branch id, or `null` when it has not been configured
/// yet (the `branchId` default is still a `[PLACEHOLDER]`; see HANDOFF).
///
/// The owner admin uses this to scope the staff list and to stamp new staff
/// onto the owner's own branch.
final currentBranchIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.branchId,
);

/// Streams the staff of [branchId] (active and inactive) for the owner-only
/// "manage staff" admin, via the shared [UsersRepository].
///
/// `autoDispose` so the subscription is dropped when the admin screen leaves
/// the tree.
final staffListProvider =
    StreamProvider.autoDispose.family<List<AppUser>, String>(
  (ref, branchId) => ref.watch(usersRepositoryProvider).watchStaff(branchId),
);
