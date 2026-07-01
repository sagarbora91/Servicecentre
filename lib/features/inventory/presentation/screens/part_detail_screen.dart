import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/entities/part.dart';
import '../controllers/inventory_write_controller.dart';
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

class _Detail extends ConsumerWidget {
  const _Detail({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canManage = ref.watch(canManageInventoryProvider);
    final isLoading = ref.watch(inventoryWriteControllerProvider).isLoading;

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
        if (canManage) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('receiveStockBtn'),
                  onPressed: isLoading
                      ? null
                      : () =>
                          unawaited(_openReceive(context, ref, part, l10n)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.receiveStockButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('adjustStockBtn'),
                  onPressed: isLoading
                      ? null
                      : () => unawaited(_openAdjust(context, ref, part, l10n)),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.adjustStockButton),
                ),
              ),
            ],
          ),
        ],
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

/// Prompts for a positive quantity and receives it into stock.
Future<void> _openReceive(
  BuildContext context,
  WidgetRef ref,
  Part part,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final qty = await showDialog<int>(
    context: context,
    builder: (_) => _StockAmountDialog(
      title: l10n.receiveStockTitle,
      label: l10n.stockQtyLabel,
      allowNegative: false,
    ),
  );
  if (qty == null) return;
  final failure = await ref
      .read(inventoryWriteControllerProvider.notifier)
      .receiveStock(partId: part.id, qty: qty);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.stockReceived : _stockFailure(failure, l10n),
      ),
    ),
  );
}

/// Prompts for a signed delta and applies it to stock (guarded at zero).
Future<void> _openAdjust(
  BuildContext context,
  WidgetRef ref,
  Part part,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final delta = await showDialog<int>(
    context: context,
    builder: (_) => _StockAmountDialog(
      title: l10n.adjustStockTitle,
      label: l10n.stockDeltaLabel,
      allowNegative: true,
    ),
  );
  if (delta == null) return;
  final failure = await ref
      .read(inventoryWriteControllerProvider.notifier)
      .adjustStock(partId: part.id, delta: delta);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.stockAdjusted : _stockFailure(failure, l10n),
      ),
    ),
  );
}

/// Localizes a stock-write [failure]: insufficient stock gets its own message,
/// anything else the generic save-failed text.
String _stockFailure(Failure failure, AppLocalizations l10n) =>
    failure is InsufficientStockFailure
        ? l10n.stockInsufficient
        : l10n.saveFailed;

/// A small dialog that collects an integer stock amount. When [allowNegative]
/// is false the value must be above zero (receive); when true it must be a
/// non-zero signed delta (adjust). Returns the parsed int via `Navigator.pop`,
/// or `null` when cancelled.
class _StockAmountDialog extends StatefulWidget {
  const _StockAmountDialog({
    required this.title,
    required this.label,
    required this.allowNegative,
  });

  final String title;
  final String label;
  final bool allowNegative;

  @override
  State<_StockAmountDialog> createState() => _StockAmountDialogState();
}

class _StockAmountDialogState extends State<_StockAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value, AppLocalizations l10n) {
    final n = int.tryParse((value ?? '').trim());
    if (n == null) {
      return widget.allowNegative
          ? l10n.stockDeltaRequired
          : l10n.stockQtyRequired;
    }
    if (widget.allowNegative) {
      if (n == 0) return l10n.stockDeltaNonZero;
    } else if (n <= 0) {
      return l10n.stockQtyPositive;
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('stockDialog'),
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('stockQtyField'),
          controller: _controller,
          autofocus: true,
          keyboardType:
              TextInputType.numberWithOptions(signed: widget.allowNegative),
          decoration: InputDecoration(labelText: widget.label),
          validator: (value) => _validate(value, l10n),
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('stockDialogCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('stockDialogConfirm'),
          onPressed: _submit,
          child: Text(l10n.stockApply),
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
