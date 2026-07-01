import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../auth_guard.dart';
import '../providers/auth_providers.dart';

/// Landing screen after sign-in. Adapts to the user's role and is the place a
/// user without a valid/active profile is bounced to, so it also explains the
/// lack of access.
class RoleHomeScreen extends ConsumerWidget {
  /// Creates the role-aware home screen.
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const Key('signOutBtn'),
            tooltip: l10n.signOutButton,
            icon: const Icon(Icons.logout),
            onPressed: () => unawaited(_signOut(context, ref, l10n)),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _CenteredMessage(message: l10n.genericError),
        data: (user) => _body(context, ref, l10n, user),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppUser? user,
  ) {
    if (user == null) {
      return _CenteredMessage(
        key: const Key('noRoleMessage'),
        message: l10n.noRoleAssigned,
      );
    }
    if (!user.active) {
      return _CenteredMessage(
        key: const Key('deactivatedMessage'),
        message: l10n.accountDeactivated,
      );
    }
    return _Dashboard(user: user, l10n: l10n);
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(authRepositoryProvider).signOut();
    if (result.isErr) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
    }
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.user, required this.l10n});

  final AppUser user;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.welcomeUser(
                  user.name.trim().isEmpty
                      ? roleLabel(user.role, l10n)
                      : user.name,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: Chip(
                  key: const Key('roleChip'),
                  label: Text(roleLabel(user.role, l10n)),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                key: const Key('openBoardBtn'),
                icon: const Icon(Icons.dashboard_outlined),
                label: Text(l10n.openBoard),
                onPressed: () => context.go(Routes.board),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('openCustomersBtn'),
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.openCustomers),
                onPressed: () => context.go(Routes.customers),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('openInventoryBtn'),
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.openInventory),
                onPressed: () => context.go(Routes.parts),
              ),
              if (user.role.canFinance) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('openBillingBtn'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.openBilling),
                  onPressed: () => context.go(Routes.billing),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('openDayBookBtn'),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(l10n.openDayBook),
                  onPressed: () => context.go(Routes.dayBook),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('openDashboardBtn'),
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(l10n.openDashboard),
                  onPressed: () => context.go(Routes.dashboard),
                ),
              ],
              if (user.role.canManageUsers) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('openAdminBtn'),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: Text(l10n.openAdminUsers),
                  onPressed: () => context.go(Routes.adminUsers),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('openImportBtn'),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(l10n.openImport),
                  onPressed: () => context.go(Routes.dataImport),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('openAuditBtn'),
                  icon: const Icon(Icons.history_outlined),
                  label: Text(l10n.openAudit),
                  onPressed: () => context.go(Routes.auditLog),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Localized label for a [UserRole].
String roleLabel(UserRole role, AppLocalizations l10n) => switch (role) {
      UserRole.owner => l10n.roleOwner,
      UserRole.supervisor => l10n.roleSupervisor,
      UserRole.counter => l10n.roleCounter,
      UserRole.technician => l10n.roleTechnician,
      UserRole.store => l10n.roleStore,
    };

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
