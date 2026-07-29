import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/utils/currency.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../../billing/domain/entities/payment.dart';
import '../../../billing/domain/entities/payment_mode.dart';
import '../../domain/accountant_export.dart';
import '../../domain/day_book.dart';
import '../providers/reports_providers.dart';

/// Day-book screen (`/reports/daybook`, finance roles): reconciles a day's
/// collections by payment mode and exports the accountant CSV. The day is
/// picked; totals come from [DayBook.fromPayments] over the branch's payments in
/// that UTC day. Money via [formatPaise].
class DayBookScreen extends ConsumerStatefulWidget {
  /// Creates the day-book screen.
  const DayBookScreen({super.key});

  @override
  ConsumerState<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends ConsumerState<DayBookScreen> {
  /// The selected day as a UTC midnight. Injected default keeps the widget
  /// deterministic; production seeds it from the current date on first build.
  DateTime? _day;

  DateTime get _from => _day ?? _todayUtc();
  DateTime get _to => _from.add(const Duration(days: 1));

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('dayBookScreen'),
      appBar: AppBar(
        title: Text(l10n.dayBookTitle),
        leading: IconButton(
          key: const Key('dayBookBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: branchId == null
          ? _centered(l10n.branchNotConfigured, const Key('dayBookNoBranch'))
          : _body(context, l10n, branchId),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, String branchId) {
    final range = (branchId: branchId, from: _from, to: _to);
    final paymentsAsync = ref.watch(paymentsInRangeProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _from.toIso8601String().substring(0, 10),
                  key: const Key('dayBookDate'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('dayBookPickDate'),
                onPressed: () => unawaited(_pickDate(context)),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(l10n.dayBookPickDate),
              ),
            ],
          ),
        ),
        Expanded(
          child: paymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                _centered(l10n.genericError, const Key('dayBookError')),
            data: (payments) => _reconciled(context, l10n, payments),
          ),
        ),
      ],
    );
  }

  Widget _reconciled(
    BuildContext context,
    AppLocalizations l10n,
    List<Payment> payments,
  ) {
    final book = DayBook.fromPayments(payments);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _row(l10n.paymentModeCash, book.amountFor(PaymentMode.cash)),
        _row(l10n.paymentModeUpi, book.amountFor(PaymentMode.upi)),
        _row(l10n.paymentModeCard, book.amountFor(PaymentMode.card)),
        const Divider(),
        _row(l10n.dayBookTotal, book.totalPaise, key: const Key('dayBookTotal')),
        _row(l10n.dayBookCount, book.count, isMoney: false),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('dayBookExportBtn'),
          onPressed: payments.isEmpty
              ? null
              : () => unawaited(_export(context, l10n, payments)),
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.dayBookExport),
        ),
      ],
    );
  }

  Widget _row(String label, int value, {bool isMoney = true, Key? key}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(isMoney ? formatPaise(value) : '$value', key: key),
          ],
        ),
      );

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100),
    );
    if (picked == null) return;
    setState(
      () => _day = DateTime.utc(picked.year, picked.month, picked.day),
    );
  }

  /// Builds the accountant CSV and writes it via the platform save dialog
  /// (device-QA; the CSV content is unit-tested in the domain layer).
  Future<void> _export(
    BuildContext context,
    AppLocalizations l10n,
    List<Payment> payments,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final csv = buildPaymentsCsv(payments);
    final fileName = 'daybook_${_from.toIso8601String().substring(0, 10)}.csv';
    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(path == null ? l10n.dayBookExportCancelled : l10n.dayBookExported),
      ),
    );
  }

  Widget _centered(String message, Key key) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, key: key, textAlign: TextAlign.center),
        ),
      );
}
