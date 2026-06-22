import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/part.dart';
import '../providers/inventory_providers.dart';

/// Part detail (`/parts/:id`, any active staff): identity (reference, category,
/// bin, size), stock figures (on-hand, reserved, available, reorder/min levels),
/// and pricing (cost, MRP). Streams the branch's parts and finds this one by id
/// so the figures update live after a stock change.
class PartDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [partId].
  const PartDetailScreen({required this.partId, super.key});

  /// The part document id from the route.
  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('partDetailScreen'),
      appBar: AppBar(
        title: Text(l10n.partDetailTitle),
        leading: IconButton(
          key: const Key('partDetailBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.parts),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('partDetailNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : ref.watch(partsProvider(branchId)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Centered(
                  key: const Key('partDetailError'),
                  message: l10n.genericError,
                ),
                data: (parts) {
                  Part? part;
                  for (final p in parts) {
                    if (p.id == partId) {
                      part = p;
                      break;
                    }
                  }
                  if (part == null) {
                    return _Centered(
                      key: const Key('partNotFound'),
                      message: l10n.partNotFound,
                    );
                  }
                  return _Detail(part: part);
                },
              ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text(part.reference, style: theme.textTheme.headlineSmall),
            ),
            if (part.isBelowReorder)
              Chip(
                key: const Key('partLowStockChip'),
                label: Text(l10n.partLowStock),
                backgroundColor: theme.colorScheme.errorContainer,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow(label: l10n.partCategoryLabel, value: part.category),
        _InfoRow(label: l10n.partBinLabel, value: part.binCode),
        if (part.size != null)
          _InfoRow(label: l10n.partSizeLabel, value: part.size!),
        const Divider(height: 32),
        _InfoRow(label: l10n.partOnHandLabel, value: '${part.onHand}'),
        _InfoRow(label: l10n.partReservedLabel, value: '${part.reserved}'),
        _InfoRow(label: l10n.partAvailableLabel, value: '${part.available}'),
        _InfoRow(label: l10n.partReorderLabel, value: '${part.reorderPoint}'),
        _InfoRow(label: l10n.partMinLevelLabel, value: '${part.minLevel}'),
        const Divider(height: 32),
        _InfoRow(
          label: l10n.partCostLabel,
          value: formatPaise(part.costPaise),
        ),
        _InfoRow(label: l10n.partMrpLabel, value: formatPaise(part.mrpPaise)),
        if (part.serviceOnly)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              l10n.partServiceOnly,
              key: const Key('partServiceOnly'),
              style: theme.textTheme.labelLarge,
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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
