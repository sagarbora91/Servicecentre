import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/part.dart';
import '../providers/inventory_providers.dart';

/// Inventory parts list (`/parts`, any active staff). Streams the branch's parts
/// and filters them live by reference, category, or bin; tapping one opens its
/// detail. On-hand is shown on each row, with a low-stock marker for parts at or
/// below their reorder point.
class PartsListScreen extends ConsumerStatefulWidget {
  /// Creates the parts list screen.
  const PartsListScreen({super.key});

  @override
  ConsumerState<PartsListScreen> createState() => _PartsListScreenState();
}

class _PartsListScreenState extends ConsumerState<PartsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('partsListScreen'),
      appBar: AppBar(
        title: Text(l10n.partsTitle),
        leading: IconButton(
          key: const Key('partsBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('partsNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : _body(l10n, branchId),
    );
  }

  Widget _body(AppLocalizations l10n, String branchId) {
    final partsAsync = ref.watch(partsProvider(branchId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('partsSearchField'),
            decoration: InputDecoration(
              hintText: l10n.partsSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: partsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _Centered(
              key: const Key('partsError'),
              message: l10n.genericError,
            ),
            data: (parts) {
              if (parts.isEmpty) {
                return _Centered(
                  key: const Key('partsEmpty'),
                  message: l10n.partsEmpty,
                );
              }
              final q = _query.trim().toLowerCase();
              final filtered =
                  q.isEmpty ? parts : parts.where((p) => _matches(p, q)).toList();
              if (filtered.isEmpty) {
                return _Centered(
                  key: const Key('partsNoMatch'),
                  message: l10n.partsNoMatch,
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final part = filtered[index];
                  return ListTile(
                    key: Key('partTile_${part.id}'),
                    leading: const CircleAvatar(child: Icon(Icons.settings)),
                    title: Text(part.reference),
                    subtitle: Text('${part.category} · ${part.binCode}'),
                    trailing: _Trailing(part: part, l10n: l10n),
                    onTap: () => context.go(Routes.partDetail(part.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Whether [part] matches the lower-cased search [q] on reference, category, or
/// bin code.
bool _matches(Part part, String q) =>
    part.reference.toLowerCase().contains(q) ||
    part.category.toLowerCase().contains(q) ||
    part.binCode.toLowerCase().contains(q);

/// Trailing on-hand count plus a low-stock marker when the part is at or below
/// its reorder point.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.part, required this.l10n});

  final Part part;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${part.onHand}', style: theme.textTheme.titleMedium),
        if (part.isBelowReorder)
          Text(
            l10n.partLowStock,
            key: Key('lowStock_${part.id}'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message, super.key});

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
