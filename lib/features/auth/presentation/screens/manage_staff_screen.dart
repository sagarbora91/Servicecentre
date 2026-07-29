import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../domain/entities/app_user.dart';
import '../auth_guard.dart';
import '../controllers/manage_staff_controller.dart';
import '../providers/staff_providers.dart';
import 'role_home_screen.dart' show roleLabel;
import 'staff_form_screen.dart';

/// Actions on a staff row.
enum _StaffAction { edit, toggleActive }

/// Owner-only "manage staff" admin: lists branch staff (active and inactive)
/// and supports add / edit / activate-deactivate, all backed by the
/// [UsersRepository]. Reached via the owner-guarded `/admin/users` route; the
/// server `firestore.rules` are the real enforcement.
class ManageStaffScreen extends ConsumerWidget {
  /// Creates the manage-staff screen.
  const ManageStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('adminUsersScreen'),
      appBar: AppBar(
        title: Text(l10n.adminUsersTitle),
        leading: IconButton(
          key: const Key('manageStaffBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      floatingActionButton: branchId == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('addStaffFab'),
              onPressed: () =>
                  unawaited(_openForm(context, ref, l10n, branchId: branchId)),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.addStaff),
            ),
      body: branchId == null
          ? _CenteredMessage(
              key: const Key('noBranchMessage'),
              message: l10n.branchNotConfigured,
            )
          : _StaffList(branchId: branchId),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required String branchId,
    AppUser? existing,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            StaffFormScreen(branchId: branchId, existing: existing),
      ),
    );
    if (saved ?? false) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.staffSaved)));
    }
  }
}

class _StaffList extends ConsumerWidget {
  const _StaffList({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final staffAsync = ref.watch(staffListProvider(branchId));

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _CenteredMessage(
        key: const Key('staffError'),
        message: l10n.genericError,
      ),
      data: (staff) {
        if (staff.isEmpty) {
          return _CenteredMessage(
            key: const Key('staffEmpty'),
            message: l10n.staffEmpty,
          );
        }
        return ListView.builder(
          itemCount: staff.length,
          itemBuilder: (context, index) =>
              _StaffTile(user: staff[index], branchId: branchId),
        );
      },
    );
  }
}

class _StaffTile extends ConsumerWidget {
  const _StaffTile({required this.user, required this.branchId});

  final AppUser user;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final displayName =
        user.name.trim().isEmpty ? roleLabel(user.role, l10n) : user.name;
    final roleAndPhone = '${roleLabel(user.role, l10n)} · ${user.phone}';
    final subtitle =
        user.active ? roleAndPhone : '$roleAndPhone · ${l10n.inactiveBadge}';

    return ListTile(
      key: Key('staffTile_${user.uid}'),
      leading: CircleAvatar(
        child: Icon(user.active ? Icons.person : Icons.person_off),
      ),
      title: Text(
        displayName,
        style: user.active ? null : TextStyle(color: theme.disabledColor),
      ),
      subtitle: Text(subtitle),
      onTap: () => unawaited(_openEdit(context, l10n)),
      trailing: PopupMenuButton<_StaffAction>(
        key: Key('staffMenu_${user.uid}'),
        onSelected: (action) {
          switch (action) {
            case _StaffAction.edit:
              unawaited(_openEdit(context, l10n));
            case _StaffAction.toggleActive:
              unawaited(_toggleActive(context, ref, l10n));
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<_StaffAction>(
            value: _StaffAction.edit,
            child: Text(l10n.editAction),
          ),
          PopupMenuItem<_StaffAction>(
            value: _StaffAction.toggleActive,
            child: Text(
              user.active ? l10n.deactivateAction : l10n.reactivateAction,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StaffFormScreen(branchId: branchId, existing: user),
      ),
    );
    if (saved ?? false) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.staffSaved)));
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (user.active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.confirmDeactivateTitle),
          content: Text(l10n.confirmDeactivateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              key: const Key('confirmDeactivateBtn'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.deactivateAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final failure = await ref
        .read(manageStaffControllerProvider.notifier)
        .setActive(user.uid, active: !user.active);
    messenger.showSnackBar(
      SnackBar(content: Text(failure == null ? l10n.staffUpdated : l10n.saveFailed)),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
