import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../domain/import_report.dart';
import '../controllers/import_controller.dart';

/// Owner-only CSV migration import (`/admin/import`). Pick a customers or parts
/// CSV → preview the validation report → import the valid rows via the existing
/// repositories. The file picker is native (device QA); the parse/preview/write
/// path is fully testable.
class ImportScreen extends ConsumerStatefulWidget {
  /// Creates the import screen.
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportKind _kind = ImportKind.customers;

  Future<void> _pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    final csv = utf8.decode(bytes, allowMalformed: true);
    final controller = ref.read(importControllerProvider.notifier);
    if (_kind == ImportKind.customers) {
      controller.previewCustomers(csv);
    } else {
      controller.previewParts(csv);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);
    final state = ref.watch(importControllerProvider);

    return Scaffold(
      key: const Key('importScreen'),
      appBar: AppBar(
        title: Text(l10n.importTitle),
        leading: IconButton(
          key: const Key('importBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('importNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : _body(l10n, state),
    );
  }

  Widget _body(AppLocalizations l10n, ImportUiState state) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<ImportKind>(
          key: const Key('importModeToggle'),
          segments: [
            ButtonSegment(
              value: ImportKind.customers,
              label: Text(l10n.importModeCustomers),
            ),
            ButtonSegment(
              value: ImportKind.parts,
              label: Text(l10n.importModeParts),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: state.busy
              ? null
              : (selection) {
                  setState(() => _kind = selection.first);
                  ref.read(importControllerProvider.notifier).reset();
                },
        ),
        const SizedBox(height: 12),
        Text(
          _kind == ImportKind.customers
              ? l10n.importCustomersHint
              : l10n.importPartsHint,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('chooseFileBtn'),
          onPressed: state.busy ? null : () => unawaited(_pickAndPreview()),
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.importChooseFile),
        ),
        const SizedBox(height: 16),
        if (state.preview != null)
          _Preview(preview: state.preview!, busy: state.busy),
        if (state.outcome != null) _Outcome(outcome: state.outcome!),
      ],
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.preview, required this.busy});

  final ImportPreview preview;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      key: const Key('importPreview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.importReadyCount('${preview.okCount}'),
          style: theme.textTheme.titleMedium,
        ),
        if (preview.errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.importProblemsCount('${preview.errors.length}'),
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
          for (final e in preview.errors)
            ListTile(
              dense: true,
              leading: const Icon(Icons.error_outline),
              title: Text(_issueLabel(e, l10n)),
              subtitle: Text(
                e.line == 0
                    ? l10n.importFileLevel
                    : l10n.importRowLabel('${e.line}'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('importBtn'),
          onPressed: (preview.okCount == 0 || busy)
              ? null
              : () => unawaited(
                    ref.read(importControllerProvider.notifier).commit(),
                  ),
          icon: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          label: Text(l10n.importButton('${preview.okCount}')),
        ),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.outcome});

  final ImportOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      key: const Key('importOutcome'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.importDone('${outcome.imported}', '${outcome.failed}'),
          style: theme.textTheme.titleMedium,
        ),
        for (final f in outcome.failures)
          ListTile(
            dense: true,
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(f.label),
            subtitle: Text(_failureLabel(f.failure, l10n)),
          ),
      ],
    );
  }
}

/// Localizes a parse [error]'s issue.
String _issueLabel(ImportError error, AppLocalizations l10n) =>
    switch (error.issue) {
      ImportIssue.missingRequiredColumn =>
        l10n.importMissingColumn(error.detail ?? ''),
      ImportIssue.missingName => l10n.importMissingName,
      ImportIssue.missingPhone => l10n.importMissingPhone,
      ImportIssue.duplicatePhoneInFile => l10n.importDuplicatePhone,
      ImportIssue.missingReference => l10n.importMissingReference,
      ImportIssue.invalidNumber => l10n.importInvalidNumber,
      ImportIssue.invalidMoney => l10n.importInvalidMoney,
    };

/// Localizes a write [failure] (duplicate vs. anything else).
String _failureLabel(Failure failure, AppLocalizations l10n) =>
    failure is ConflictFailure
        ? l10n.importDuplicateExisting
        : l10n.importWriteFailed;

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
