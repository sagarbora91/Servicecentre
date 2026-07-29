import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../../feedback/presentation/widgets/feedback_section.dart';
import '../../../inventory/domain/entities/part.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../domain/entities/delivery_gate.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_photo_kind.dart';
import '../../domain/entities/job_qc.dart';
import '../../domain/entities/job_status.dart';
import '../controllers/job_detail_controller.dart';
import '../job_slip_pdf.dart';
import '../jobs_labels.dart';
import '../providers/jobs_providers.dart';

/// Job detail (`/jobs/:id`, any active staff): all fields, the status timeline,
/// the QC checklist editor, status-move actions, and the gated Deliver button.
class JobDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [jobId].
  const JobDetailScreen({required this.jobId, super.key});

  /// The job document id from the route.
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jobAsync = ref.watch(jobByIdProvider(jobId));

    return Scaffold(
      key: const Key('jobDetailScreen'),
      appBar: AppBar(
        title: Text(l10n.jobDetailTitle),
        leading: IconButton(
          key: const Key('jobDetailBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.board),
        ),
        actions: [
          IconButton(
            key: const Key('openLabelBtn'),
            tooltip: l10n.openLabel,
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => context.go(Routes.jobLabel(jobId)),
          ),
        ],
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Centered(
          key: const Key('jobDetailError'),
          message: l10n.genericError,
        ),
        data: (job) => job == null
            ? _Centered(
                key: const Key('jobNotFound'),
                message: l10n.jobNotFound,
              )
            : _Detail(job: job),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLoading = ref.watch(jobDetailControllerProvider).isLoading;
    final canLogParts = ref.watch(canLogJobPartsProvider);

    final customers = ref.watch(customersProvider(job.branchId)).valueOrNull ??
        const <Customer>[];
    String? customerName;
    for (final c in customers) {
      if (c.id == job.customerId) {
        customerName = c.name;
        break;
      }
    }

    final dueText =
        MaterialLocalizations.of(context).formatShortDate(job.dueAt.toLocal());
    final qc = job.qc ??
        const JobQc(
          timekeeping: false,
          gasket: false,
          glassClean: false,
          strap: false,
          crown: false,
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Row(
          children: [
            Expanded(
              child: Text(job.jobNo, style: theme.textTheme.headlineSmall),
            ),
            Chip(
              key: const Key('jobStatusChip'),
              label: Text(jobStatusLabel(job.status, l10n)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('printSlipBtn'),
          onPressed: () => unawaited(
            _printSlip(context, l10n, job, customerName ?? job.customerId),
          ),
          icon: const Icon(Icons.print_outlined),
          label: Text(l10n.printSlipAction),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('openEstimatesBtn'),
          onPressed: () => context.go(Routes.jobEstimate(job.id)),
          icon: const Icon(Icons.request_quote_outlined),
          label: Text(l10n.jobDetailEstimatesButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('openInvoicesBtn'),
          onPressed: () => context.go(Routes.jobInvoice(job.id)),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l10n.jobDetailInvoicesButton),
        ),
        const SizedBox(height: 12),
        _InfoRow(label: l10n.detailCustomer, value: customerName ?? job.customerId),
        _InfoRow(label: l10n.detailFault, value: job.fault),
        _InfoRow(label: l10n.detailWork, value: job.workRequested),
        _InfoRow(label: l10n.detailDue, value: dueText),
        if (job.sourceStore != null)
          _InfoRow(
            label: l10n.detailSourceStore,
            value: job.sourceStore!,
          ),
        const Divider(height: 32),

        // Photos (intake + delivery). A delivery photo unblocks the gate.
        Text(l10n.photosSection, style: theme.textTheme.titleMedium),
        _InfoRow(
          label: l10n.intakePhotosLabel,
          value: '${job.intakePhotos.length}',
        ),
        _InfoRow(
          label: l10n.deliveryPhotosLabel,
          value: '${job.deliveryPhotos.length}',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('addIntakePhotoBtn'),
                onPressed: isLoading
                    ? null
                    : () => unawaited(
                        _addPhoto(
                          context,
                          ref,
                          job.id,
                          JobPhotoKind.intake,
                          l10n,
                        ),
                      ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(l10n.addIntakePhoto),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('addDeliveryPhotoBtn'),
                onPressed: isLoading
                    ? null
                    : () => unawaited(
                        _addPhoto(
                          context,
                          ref,
                          job.id,
                          JobPhotoKind.delivery,
                          l10n,
                        ),
                      ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(l10n.addDeliveryPhoto),
              ),
            ),
          ],
        ),
        const Divider(height: 32),

        // QC checklist editor.
        Text(l10n.qcSectionTitle, style: theme.textTheme.titleMedium),
        _QcTile(
          field: 'timekeeping',
          label: l10n.qcTimekeeping,
          value: qc.timekeeping,
          enabled: !isLoading,
          onChanged: (v) => unawaited(
            _saveQc(context, ref, job.id, qc.copyWith(timekeeping: v), l10n),
          ),
        ),
        _QcTile(
          field: 'gasket',
          label: l10n.qcGasket,
          value: qc.gasket,
          enabled: !isLoading,
          onChanged: (v) => unawaited(
            _saveQc(context, ref, job.id, qc.copyWith(gasket: v), l10n),
          ),
        ),
        _QcTile(
          field: 'glassClean',
          label: l10n.qcGlassClean,
          value: qc.glassClean,
          enabled: !isLoading,
          onChanged: (v) => unawaited(
            _saveQc(context, ref, job.id, qc.copyWith(glassClean: v), l10n),
          ),
        ),
        _QcTile(
          field: 'strap',
          label: l10n.qcStrap,
          value: qc.strap,
          enabled: !isLoading,
          onChanged: (v) => unawaited(
            _saveQc(context, ref, job.id, qc.copyWith(strap: v), l10n),
          ),
        ),
        _QcTile(
          field: 'crown',
          label: l10n.qcCrown,
          value: qc.crown,
          enabled: !isLoading,
          onChanged: (v) => unawaited(
            _saveQc(context, ref, job.id, qc.copyWith(crown: v), l10n),
          ),
        ),
        const Divider(height: 32),

        // Parts used.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.partsUsedSection,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (canLogParts)
              TextButton.icon(
                key: const Key('addPartBtn'),
                onPressed: isLoading
                    ? null
                    : () => unawaited(_openAddPart(context, ref, job, l10n)),
                icon: const Icon(Icons.add),
                label: Text(l10n.addPartButton),
              ),
          ],
        ),
        if (job.partsUsed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.noPartsUsed, key: const Key('noPartsUsed')),
          )
        else
          for (final jp in job.partsUsed)
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_outlined),
              title: Text(jp.ref),
              trailing: Text('×${jp.qty}'),
            ),
        const Divider(height: 32),

        // Status actions.
        Text(l10n.statusActionsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final to in allowedTransitions(job.status))
          if (to == JobStatus.delivered)
            _DeliverAction(job: job, isLoading: isLoading)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('moveTo_${to.wireName}'),
                onPressed: isLoading
                    ? null
                    : () => unawaited(_move(context, ref, job.id, to, l10n)),
                child: Text(l10n.moveToStatus(jobStatusLabel(to, l10n))),
              ),
            ),
        const Divider(height: 32),

        // Customer feedback (delivered jobs only).
        if (job.status == JobStatus.delivered) ...[
          Text(l10n.feedbackLabel, style: theme.textTheme.titleMedium),
          FeedbackSection(jobId: job.id),
          const Divider(height: 32),
        ],

        // Status timeline.
        Text(l10n.detailHistory, style: theme.textTheme.titleMedium),
        for (final change in job.statusHistory)
          ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text(jobStatusLabel(change.status, l10n)),
            subtitle: Text(
              MaterialLocalizations.of(context)
                  .formatShortDate(change.at.toLocal()),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Deliver button + (when blocked) the localized gate reason. Disabled until
/// the job satisfies the delivery gate (complete QC + a delivery photo).
class _DeliverAction extends ConsumerWidget {
  const _DeliverAction({required this.job, required this.isLoading});

  final Job job;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reason = _gateReason(job, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('deliverBtn'),
          onPressed: (job.canDeliver && !isLoading)
              ? () => unawaited(_deliver(context, ref, job.id, l10n))
              : null,
          icon: const Icon(Icons.local_shipping_outlined),
          label: Text(l10n.deliverButton),
        ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              reason,
              key: const Key('deliverGateReason'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _QcTile extends StatelessWidget {
  const _QcTile({
    required this.field,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String field;
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: Key('qc_$field'),
      title: Text(label),
      value: value,
      onChanged: enabled ? onChanged : null,
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

String? _gateReason(Job job, AppLocalizations l10n) =>
    switch (deliveryGateResult(job)) {
      DeliveryGate.ready => null,
      DeliveryGate.qcMissing ||
      DeliveryGate.qcIncomplete =>
        l10n.gateQcIncomplete,
      DeliveryGate.noDeliveryPhoto => l10n.gateNoPhoto,
    };

String _failureMessage(Failure failure, AppLocalizations l10n) {
  if (failure is InsufficientStockFailure) return l10n.stockInsufficient;
  if (failure is ValidationFailure) {
    return switch (failure.reason) {
      ValidationReason.deliveryQcIncomplete => l10n.gateQcIncomplete,
      ValidationReason.deliveryNoPhoto => l10n.gateNoPhoto,
      // paymentExceedsBalance is handled on the invoice screen; feedback rating
      // is validated in the dialog. Kept for switch exhaustiveness.
      ValidationReason.paymentExceedsBalance ||
      ValidationReason.feedbackRatingInvalid =>
        l10n.saveFailed,
    };
  }
  return l10n.saveFailed;
}

/// Captures a photo (camera), compresses it to JPEG, and uploads it as a [kind]
/// photo for [jobId]. The capture + compress are native (device-QA); the
/// upload→record path is unit-tested via the controller.
Future<void> _addPhoto(
  BuildContext context,
  WidgetRef ref,
  String jobId,
  JobPhotoKind kind,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null) return;
  final raw = await picked.readAsBytes();
  final compressed = await FlutterImageCompress.compressWithList(
    raw,
    quality: 70,
  );
  final failure = await ref
      .read(jobDetailControllerProvider.notifier)
      .addPhoto(jobId, kind, compressed);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.photoAdded : _failureMessage(failure, l10n),
      ),
    ),
  );
}

/// Builds a localized job slip and opens the native print/share dialog
/// (device-QA; the PDF builder itself is unit-tested).
Future<void> _printSlip(
  BuildContext context,
  AppLocalizations l10n,
  Job job,
  String customerName,
) {
  final dueText =
      MaterialLocalizations.of(context).formatShortDate(job.dueAt.toLocal());
  final data = JobSlipData(
    title: l10n.jobSlipTitle,
    jobNo: job.jobNo,
    rows: [
      JobSlipRow(l10n.detailCustomer, customerName),
      JobSlipRow(l10n.detailFault, job.fault),
      JobSlipRow(l10n.detailWork, job.workRequested),
      JobSlipRow(l10n.detailDue, dueText),
    ],
    partsLabel: l10n.partsUsedSection,
    parts: [for (final p in job.partsUsed) '${p.ref} x${p.qty}'],
    footer: l10n.appTitle,
  );
  return Printing.layoutPdf(onLayout: (_) => buildJobSlipPdf(data));
}

Future<void> _move(
  BuildContext context,
  WidgetRef ref,
  String id,
  JobStatus to,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failure =
      await ref.read(jobDetailControllerProvider.notifier).move(id, to);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.statusUpdated : _failureMessage(failure, l10n),
      ),
    ),
  );
}

Future<void> _deliver(
  BuildContext context,
  WidgetRef ref,
  String id,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failure =
      await ref.read(jobDetailControllerProvider.notifier).deliver(id);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.deliveredSnack : _failureMessage(failure, l10n),
      ),
    ),
  );
}

Future<void> _saveQc(
  BuildContext context,
  WidgetRef ref,
  String id,
  JobQc qc,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failure =
      await ref.read(jobDetailControllerProvider.notifier).updateQc(id, qc);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.qcSaved : _failureMessage(failure, l10n),
      ),
    ),
  );
}

/// Opens the add-part picker for [job] and, on confirm, logs the chosen part:
/// the controller decrements stock transactionally then records it on the job.
Future<void> _openAddPart(
  BuildContext context,
  WidgetRef ref,
  Job job,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final selection = await showDialog<_PartSelection>(
    context: context,
    builder: (_) => _AddPartDialog(branchId: job.branchId),
  );
  if (selection == null) return;
  final failure =
      await ref.read(jobDetailControllerProvider.notifier).addPart(
            job.id,
            partId: selection.partId,
            qty: selection.qty,
            reference: selection.reference,
          );
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure == null ? l10n.partAddedSnack : _failureMessage(failure, l10n),
      ),
    ),
  );
}

/// A chosen part line returned by [_AddPartDialog].
class _PartSelection {
  const _PartSelection({
    required this.partId,
    required this.qty,
    required this.reference,
  });

  final String partId;
  final int qty;
  final String reference;
}

/// Dialog to pick a part and quantity to log on a job. Watches the branch's
/// parts so the list is live, and returns a [_PartSelection] via
/// `Navigator.pop` (or `null` when cancelled / no parts exist).
class _AddPartDialog extends ConsumerStatefulWidget {
  const _AddPartDialog({required this.branchId});

  final String branchId;

  @override
  ConsumerState<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends ConsumerState<_AddPartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController(text: '1');
  String? _partId;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _submit(List<Part> parts) {
    if (!_formKey.currentState!.validate()) return;
    final part = parts.firstWhere((p) => p.id == _partId);
    Navigator.of(context).pop(
      _PartSelection(
        partId: part.id,
        qty: int.parse(_qty.text.trim()),
        reference: part.reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts =
        ref.watch(partsProvider(widget.branchId)).valueOrNull ?? const <Part>[];
    return AlertDialog(
      key: const Key('addPartDialog'),
      title: Text(l10n.addPartTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (parts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.partsEmpty, key: const Key('addPartEmpty')),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const Key('partDropdown'),
                initialValue: _partId,
                decoration: InputDecoration(labelText: l10n.addPartLabel),
                items: [
                  for (final p in parts)
                    DropdownMenuItem<String>(
                      value: p.id,
                      child: Text('${p.reference} (${p.onHand})'),
                    ),
                ],
                onChanged: (value) => setState(() => _partId = value),
                validator: (value) =>
                    value == null ? l10n.addPartSelect : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('partQtyField'),
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.stockQtyLabel),
                validator: (value) {
                  final n = int.tryParse((value ?? '').trim());
                  return (n == null || n <= 0) ? l10n.stockQtyPositive : null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('addPartCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('addPartConfirm'),
          onPressed: parts.isEmpty ? null : () => _submit(parts),
          child: Text(l10n.stockApply),
        ),
      ],
    );
  }
}
