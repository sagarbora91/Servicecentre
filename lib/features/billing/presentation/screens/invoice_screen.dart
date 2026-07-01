import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../../jobs/domain/entities/payment_status.dart';
import '../../../jobs/presentation/providers/jobs_providers.dart';
import '../../../settings/domain/entities/branch_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_line.dart';
import '../../domain/services/gst_calculator.dart';
import '../controllers/invoice_controller.dart';
import '../invoice_pdf.dart';
import '../providers/billing_providers.dart';

/// Invoice screen for a job (`/jobs/:id/invoice`).
///
/// Lists the job's invoices and lets finance roles (owner/supervisor) build a
/// new one line-by-line (per-line GST%) and print it. GST presentation is
/// driven by [BranchSettings.gstEnabled] (m7-decisions): off → a bill of supply;
/// on → a tax invoice with GSTIN/HSN/CGST/SGST. Money via [formatPaise].
class InvoiceScreen extends ConsumerStatefulWidget {
  /// Creates the invoice screen for [jobId].
  const InvoiceScreen({required this.jobId, super.key});

  /// The job document id from the route.
  final String jobId;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  final List<InvoiceLine> _draft = [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canFinance = ref.watch(canFinanceProvider);
    final branchId = ref.watch(currentBranchIdProvider);
    final invoicesAsync = ref.watch(invoicesForJobProvider(widget.jobId));
    final customerName = _customerName(branchId);

    return Scaffold(
      key: const Key('invoiceScreen'),
      appBar: AppBar(
        title: Text(l10n.invoicesTitle),
        leading: IconButton(
          key: const Key('invoiceBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.jobDetail(widget.jobId)),
        ),
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.genericError,
              key: const Key('invoiceError'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (invoices) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (invoices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.invoiceEmpty,
                    key: const Key('invoiceEmpty'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final invoice in invoices)
                _InvoiceCard(
                  invoice: invoice,
                  customerName: customerName,
                  onPrint: () => unawaited(
                    _print(l10n, invoice, customerName, branchId),
                  ),
                ),
              if (canFinance) _builder(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _builder(BuildContext context, AppLocalizations l10n) {
    final busy = ref.watch(invoiceControllerProvider).isLoading;
    return Card(
      key: const Key('invoiceBuilder'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.invoiceNewButton, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _draft.length; i++)
              Row(
                children: [
                  Expanded(child: Text('${_draft[i].desc} x${_draft[i].qty}')),
                  Text(formatPaise(_draft[i].taxablePaise)),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('invoiceAddLineBtn'),
                    onPressed:
                        busy ? null : () => unawaited(_addLine(context)),
                    child: Text(l10n.invoiceAddLineButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('invoiceCreateBtn'),
                    onPressed: (busy || _draft.isEmpty)
                        ? null
                        : () => unawaited(_create(context, l10n)),
                    child: Text(l10n.invoiceCreateButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _customerName(String? branchId) {
    final job = ref.watch(jobByIdProvider(widget.jobId)).valueOrNull;
    if (job == null || branchId == null) return '';
    final customers = ref.watch(customersProvider(branchId)).valueOrNull ?? [];
    for (final c in customers) {
      if (c.id == job.customerId) return c.name;
    }
    return job.customerId;
  }

  Future<void> _addLine(BuildContext context) async {
    final line = await showDialog<InvoiceLine>(
      context: context,
      builder: (_) => const _InvoiceLineDialog(),
    );
    if (line == null) return;
    setState(() => _draft.add(line));
  }

  Future<void> _create(BuildContext context, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await ref
        .read(invoiceControllerProvider.notifier)
        .createInvoice(jobId: widget.jobId, lines: List.of(_draft));
    if (failure == null) setState(_draft.clear);
    messenger.showSnackBar(
      SnackBar(
        content: Text(failure == null ? l10n.invoiceSaved : l10n.saveFailed),
      ),
    );
  }

  Future<void> _print(
    AppLocalizations l10n,
    Invoice invoice,
    String customerName,
    String? branchId,
  ) async {
    final settings = branchId == null
        ? BranchSettings.defaults('')
        : ref.read(branchSettingsProvider(branchId)).valueOrNull ??
            BranchSettings.defaults(branchId);
    final data = _pdfData(l10n, invoice, customerName, settings);
    await Printing.layoutPdf(onLayout: (_) => buildInvoicePdf(data));
  }
}

/// Builds the (localized, ₹-formatted) invoice PDF content from the domain
/// [invoice] and [settings]. A tax invoice when [BranchSettings.gstEnabled];
/// otherwise a bill of supply (no HSN/GST columns or tax rows).
InvoicePdfData _pdfData(
  AppLocalizations l10n,
  Invoice invoice,
  String customerName,
  BranchSettings settings,
) {
  final showTax = settings.gstEnabled && invoice.hasTax;
  final breakdown = GstCalculator.invoiceBreakdown(
    invoice.lines,
    place: invoice.place,
  );
  final intra = invoice.place == GstPlace.intraState;
  return InvoicePdfData(
    title: showTax ? l10n.invoicePdfTaxTitle : l10n.invoicePdfBillTitle,
    number: invoice.number,
    sellerName: settings.legalName ?? l10n.appTitle,
    sellerGstin: settings.gstin,
    sellerAddress: settings.address,
    customerName: customerName,
    columnDesc: l10n.invoiceColItem,
    columnHsn: l10n.invoiceColHsn,
    columnQty: l10n.invoiceColQty,
    columnRate: l10n.invoiceColRate,
    columnGst: l10n.invoiceColGst,
    columnAmount: l10n.invoiceColAmount,
    lines: [
      for (final line in invoice.lines)
        InvoicePdfLine(
          desc: line.desc,
          hsn: line.hsn,
          qty: line.qty,
          rate: formatPaise(line.ratePaise),
          gstPct: line.gstPct,
          amount: formatPaise(line.taxablePaise),
        ),
    ],
    taxableLabel: showTax ? l10n.invoiceTaxableLabel : l10n.invoiceSubtotalLabel,
    taxable: formatPaise(invoice.taxablePaise),
    cgstLabel: intra ? l10n.invoiceCgstLabel : null,
    cgst: intra ? formatPaise(breakdown.cgstPaise) : null,
    sgstLabel: intra ? l10n.invoiceSgstLabel : null,
    sgst: intra ? formatPaise(breakdown.sgstPaise) : null,
    igstLabel: intra ? null : l10n.invoiceIgstLabel,
    igst: intra ? null : formatPaise(breakdown.igstPaise),
    totalLabel: l10n.invoiceTotalLabel,
    total: formatPaise(invoice.totalPaise),
    footer: l10n.invoicePdfFooter,
    showTax: showTax,
  );
}

String paymentStatusLabel(PaymentStatus status, AppLocalizations l10n) =>
    switch (status) {
      PaymentStatus.paid => l10n.invoiceStatusPaid,
      PaymentStatus.partial => l10n.invoiceStatusPartial,
      PaymentStatus.unpaid || PaymentStatus.unbilled => l10n.invoiceStatusUnpaid,
    };

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.customerName,
    required this.onPrint,
  });

  final Invoice invoice;
  final String customerName;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: Key('invoiceCard_${invoice.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(invoice.number, style: theme.textTheme.titleMedium),
                ),
                Chip(label: Text(paymentStatusLabel(invoice.paymentStatus, l10n))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(l10n.invoiceTotalLabel)),
                Text(
                  formatPaise(invoice.totalPaise),
                  key: Key('invoiceTotal_${invoice.id}'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: Key('invoicePrintBtn_${invoice.id}'),
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.invoicePrintButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collects one invoice line (description, quantity, unit rate in ₹, GST%) and
/// returns it as an [InvoiceLine] via `Navigator.pop`, or `null` when cancelled.
class _InvoiceLineDialog extends StatefulWidget {
  const _InvoiceLineDialog();

  @override
  State<_InvoiceLineDialog> createState() => _InvoiceLineDialogState();
}

class _InvoiceLineDialogState extends State<_InvoiceLineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController();
  final _gstController = TextEditingController(text: '0');

  @override
  void dispose() {
    _descController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      InvoiceLine(
        desc: _descController.text.trim(),
        qty: int.parse(_qtyController.text.trim()),
        ratePaise: parseRupeesToPaise(_rateController.text)!,
        gstPct: int.parse(_gstController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('invoiceLineDialog'),
      title: Text(l10n.invoiceLineAddTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('invoiceLineDescField'),
              controller: _descController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.estimateLineDescLabel),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.estimateLineDescRequired
                  : null,
            ),
            TextFormField(
              key: const Key('invoiceLineQtyField'),
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.invoiceLineQtyLabel),
              validator: (value) {
                final n = int.tryParse((value ?? '').trim());
                return (n == null || n <= 0) ? l10n.invoiceLineQtyInvalid : null;
              },
            ),
            TextFormField(
              key: const Key('invoiceLineRateField'),
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.invoiceLineRateLabel),
              validator: (value) => parseRupeesToPaise(value ?? '') == null
                  ? l10n.estimateAmountInvalid
                  : null,
            ),
            TextFormField(
              key: const Key('invoiceLineGstField'),
              controller: _gstController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.invoiceLineGstLabel),
              validator: (value) {
                final n = int.tryParse((value ?? '').trim());
                return (n == null || n < 0) ? l10n.invoiceLineGstInvalid : null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('invoiceLineCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('invoiceLineConfirm'),
          onPressed: _submit,
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }
}
