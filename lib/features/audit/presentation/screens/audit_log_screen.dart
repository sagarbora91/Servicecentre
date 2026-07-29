import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../providers/audit_providers.dart';

/// Audit-trail screen (`/admin/audit`, owner): the recent append-only
/// `activityLog` entries, newest first (BUILD_BRIEF §12 M10 "activityLog
/// surfaced").
class AuditLogScreen extends ConsumerWidget {
  /// Creates the audit-log screen.
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      key: const Key('auditLogScreen'),
      appBar: AppBar(
        title: Text(l10n.auditTitle),
        leading: IconButton(
          key: const Key('auditBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.genericError,
              key: const Key('auditError'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text(l10n.auditEmpty, key: const Key('auditEmpty')),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final when = e.at?.toIso8601String().replaceFirst('T', ' ') ?? '';
              return ListTile(
                key: Key('auditEntry_${e.id}'),
                dense: true,
                title: Text(e.action),
                subtitle: Text('${e.entity}/${e.entityId} · ${e.actor}'),
                trailing: Text(
                  when.length >= 16 ? when.substring(0, 16) : when,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
