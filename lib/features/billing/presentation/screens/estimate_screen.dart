import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../domain/entities/estimate.dart';
import '../../domain/entities/estimate_line.dart';
import '../../domain/entities/estimate_status.dart';
import '../controllers/estimate_controller.dart';
import '../providers/billing_providers.dart';

/// Estimate (customer quote) screen for a job (`/jobs/:id/estimate`).
///
/// Lists the job's estimates newest-first, and — for staff who [canQuote]
/// (owner/supervisor/counter) — lets them create a draft, add lines, mark it
/// sent, and record the customer's approval or decline. Read-only for other
/// staff. All money is displayed via [formatPaise].
class EstimateScreen extends ConsumerWidget {
  /// Creates the estimate screen for [jobId].
  const EstimateScreen({required this.jobId, super.key});

  /// The job document id from the route.
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canQuote = ref.watch(canQuoteProvider);
    final estimatesAsync = ref.watch(estimatesForJobProvider(jobId));

    return Scaffold(
      key: const Key('estimateScreen'),
      appBar: AppBar(
        title: Text(l10n.estimatesTitle),
        leading: IconButton(
          key: const Key('estimateBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.jobDetail(jobId)),
        ),
      ),
      floatingActionButton: canQuote
          ? FloatingActionButton.extended(
              key: const Key('newEstimateBtn'),
              onPressed: () => unawaited(_createDraft(context, ref, l10n, jobId)),
              icon: const Icon(Icons.add),
              label: Text(l10n.estimateNewButton),
            )
          : null,
      body: estimatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Centered(
          key: const Key('estimateError'),
          message: l10n.genericError,
        ),
        data: (estimates) {
          if (estimates.isEmpty) {
            return _Centered(
              key: const Key('estimateEmpty'),
              message: l10n.estimateEmpty,
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final estimate in estimates)
                  _EstimateCard(
                    estimate: estimate,
                    canQuote: canQuote,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EstimateCard extends ConsumerWidget {
  const _EstimateCard({required this.estimate, required this.canQuote});

  final Estimate estimate;
  final bool canQuote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(estimateControllerProvider).isLoading;
    final editable = estimate.status == EstimateStatus.draft ||
        estimate.status == EstimateStatus.sent;

    return Card(
      key: Key('estimateCard_${estimate.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                key: Key('estimateStatus_${estimate.id}'),
                label: Text(_statusLabel(estimate.status, l10n)),
              ),
            ),
            const SizedBox(height: 8),
            for (final line in estimate.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(line.desc)),
                    Text(formatPaise(line.amountPaise)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.estimateTotalLabel,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatPaise(estimate.totalPaise),
                  key: const Key('estimateTotal'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (estimate.approvedVia != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.estimateApprovedVia(estimate.approvedVia!),
                key: const Key('estimateApprovedVia'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (canQuote && editable) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('estimateAddLineBtn'),
                    onPressed: busy
                        ? null
                        : () => unawaited(_addLine(context, ref, l10n)),
                    child: Text(l10n.estimateAddLine),
                  ),
                  if (estimate.status == EstimateStatus.draft)
                    OutlinedButton(
                      key: const Key('estimateMarkSentBtn'),
                      onPressed: busy
                          ? null
                          : () => unawaited(_markSent(context, ref, l10n)),
                      child: Text(l10n.estimateMarkSent),
                    ),
                  FilledButton(
                    key: const Key('estimateApproveBtn'),
                    onPressed: busy
                        ? null
                        : () => unawaited(_approve(context, ref, l10n)),
                    child: Text(l10n.estimateApprove),
                  ),
                  OutlinedButton(
                    key: const Key('estimateDeclineBtn'),
                    onPressed: busy
                        ? null
                        : () => unawaited(_decline(context, ref, l10n)),
                    child: Text(l10n.estimateDecline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addLine(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final line = await showDialog<EstimateLine>(
      context: context,
      builder: (_) => _LineDialog(title: l10n.estimateAddLineTitle),
    );
    if (line == null) return;
    final failure = await ref
        .read(estimateControllerProvider.notifier)
        .updateLines(estimate.id, [...estimate.lines, line]);
    _report(messenger, failure, l10n);
  }

  Future<void> _markSent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure =
        await ref.read(estimateControllerProvider.notifier).markSent(estimate.id);
    _report(messenger, failure, l10n);
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure =
        await ref.read(estimateControllerProvider.notifier).approve(estimate.id);
    _report(messenger, failure, l10n);
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure =
        await ref.read(estimateControllerProvider.notifier).decline(estimate.id);
    _report(messenger, failure, l10n);
  }
}

/// Opens the line dialog and creates a draft estimate for [jobId] from the
/// entered line.
Future<void> _createDraft(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  String jobId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final line = await showDialog<EstimateLine>(
    context: context,
    builder: (_) => _LineDialog(title: l10n.estimateNewTitle),
  );
  if (line == null) return;
  final failure = await ref
      .read(estimateControllerProvider.notifier)
      .createDraft(jobId: jobId, lines: [line]);
  _report(messenger, failure, l10n);
}

void _report(
  ScaffoldMessengerState messenger,
  Object? failure,
  AppLocalizations l10n,
) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(failure == null ? l10n.estimateSaved : l10n.saveFailed),
    ),
  );
}

String _statusLabel(EstimateStatus status, AppLocalizations l10n) =>
    switch (status) {
      EstimateStatus.draft => l10n.estimateStatusDraft,
      EstimateStatus.sent => l10n.estimateStatusSent,
      EstimateStatus.approved => l10n.estimateStatusApproved,
      EstimateStatus.declined => l10n.estimateStatusDeclined,
    };

/// Collects a single estimate line (description + rupee amount) and returns it
/// as an [EstimateLine] via `Navigator.pop`, or `null` when cancelled.
class _LineDialog extends StatefulWidget {
  const _LineDialog({required this.title});

  final String title;

  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final paise = parseRupeesToPaise(_amountController.text)!;
    Navigator.of(context).pop(
      EstimateLine(desc: _descController.text.trim(), amountPaise: paise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('estimateLineDialog'),
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('estimateLineDescField'),
              controller: _descController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.estimateLineDescLabel),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.estimateLineDescRequired
                  : null,
            ),
            TextFormField(
              key: const Key('estimateLineAmountField'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: l10n.estimateLineAmountLabel),
              validator: (value) => parseRupeesToPaise(value ?? '') == null
                  ? l10n.estimateAmountInvalid
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('estimateLineCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('estimateLineConfirm'),
          onPressed: _submit,
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
