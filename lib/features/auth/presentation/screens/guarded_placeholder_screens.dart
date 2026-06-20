import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../auth_guard.dart';

/// Placeholder for the finance area, reachable only by finance roles. The real
/// billing UI arrives in M7; this exists in M1 to exercise the role guard.
class BillingScreen extends StatelessWidget {
  /// Creates the billing placeholder.
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Placeholder(
      key: const Key('billingScreen'),
      title: l10n.billingTitle,
      message: l10n.comingSoon,
    );
  }
}

/// Placeholder for staff management, reachable only by the owner. Real role
/// assignment UI is fleshed out later; this exercises the owner-only guard.
class AdminUsersScreen extends StatelessWidget {
  /// Creates the admin-users placeholder.
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Placeholder(
      key: const Key('adminUsersScreen'),
      title: l10n.adminUsersTitle,
      message: l10n.comingSoon,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          key: const Key('placeholderBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
