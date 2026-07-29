import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../../inventory/domain/entities/part.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../domain/customer_import.dart';
import '../../domain/import_report.dart';
import '../../domain/part_import.dart';

/// Which dataset an import is operating on.
enum ImportKind { customers, parts }

/// A parse preview: how many rows are importable and what failed validation.
class ImportPreview {
  /// Creates a parse preview.
  const ImportPreview({
    required this.kind,
    required this.okCount,
    required this.errors,
  });

  /// The dataset previewed.
  final ImportKind kind;

  /// Rows that validated cleanly and would be written.
  final int okCount;

  /// Per-row / file-level parse problems.
  final List<ImportError> errors;
}

/// One row that parsed cleanly but failed to write (e.g. a duplicate phone
/// against existing data). [label] identifies the row for the user.
class ImportWriteFailure {
  /// Creates a write failure.
  const ImportWriteFailure({required this.label, required this.failure});

  /// A human label for the row (customer name+phone, or part reference).
  final String label;

  /// The repository failure, localized by the UI.
  final Failure failure;
}

/// The outcome of committing an import: how many rows were written and which
/// failed.
class ImportOutcome {
  /// Creates an import outcome.
  const ImportOutcome({
    required this.kind,
    required this.imported,
    required this.failures,
  });

  /// The dataset imported.
  final ImportKind kind;

  /// Number of rows successfully written.
  final int imported;

  /// Rows that could not be written.
  final List<ImportWriteFailure> failures;

  /// Number of rows that failed to write.
  int get failed => failures.length;
}

/// Import screen state: the current [preview] (after picking a file), the
/// [outcome] (after committing), and whether a write is in flight.
class ImportUiState {
  /// Creates the import UI state.
  const ImportUiState({this.preview, this.outcome, this.busy = false});

  /// The latest parse preview, or `null` before a file is chosen.
  final ImportPreview? preview;

  /// The latest import outcome, or `null` before committing.
  final ImportOutcome? outcome;

  /// Whether a write is in progress.
  final bool busy;
}

/// Orchestrates a CSV migration import: parse → preview → write valid rows via
/// the existing customer/inventory repositories, collecting per-row failures.
class ImportController extends AutoDisposeNotifier<ImportUiState> {
  List<CustomerImportRow> _customers = const [];
  List<PartImportRow> _parts = const [];

  @override
  ImportUiState build() => const ImportUiState();

  String get _uid => ref.read(currentUserProvider).valueOrNull?.uid ?? '';

  /// Parses a customers CSV and shows its preview, stashing the valid rows.
  void previewCustomers(String csv) {
    final report = parseCustomersCsv(csv);
    _customers = report.valid;
    _parts = const [];
    state = ImportUiState(
      preview: ImportPreview(
        kind: ImportKind.customers,
        okCount: report.okCount,
        errors: report.errors,
      ),
    );
  }

  /// Parses a parts CSV and shows its preview, stashing the valid rows.
  void previewParts(String csv) {
    final report = parsePartsCsv(csv);
    _parts = report.valid;
    _customers = const [];
    state = ImportUiState(
      preview: ImportPreview(
        kind: ImportKind.parts,
        okCount: report.okCount,
        errors: report.errors,
      ),
    );
  }

  /// Clears any preview/outcome (e.g. when switching dataset).
  void reset() {
    _customers = const [];
    _parts = const [];
    state = const ImportUiState();
  }

  /// Writes the previewed valid rows. No-op without a preview, off-branch, or
  /// while already busy. Surfaces per-row write failures in the [ImportOutcome].
  Future<void> commit() async {
    final preview = state.preview;
    if (preview == null || state.busy) return;
    final branchId = ref.read(currentBranchIdProvider);
    if (branchId == null) return;
    state = ImportUiState(preview: preview, busy: true);

    final outcome = preview.kind == ImportKind.customers
        ? await _commitCustomers(branchId)
        : await _commitParts(branchId);
    state = ImportUiState(outcome: outcome);
  }

  Future<ImportOutcome> _commitCustomers(String branchId) async {
    final repo = ref.read(customersRepositoryProvider);
    final failures = <ImportWriteFailure>[];
    var imported = 0;
    for (final row in _customers) {
      final result = await repo.createCustomer(
        branchId: branchId,
        name: row.name,
        phone: row.phone,
        uid: _uid,
        consentWhatsApp: row.consentWhatsApp,
        email: row.email,
        address: row.address,
      );
      final failure = result.failureOrNull;
      if (failure != null) {
        failures.add(
          ImportWriteFailure(
            label: '${row.name} (${row.phone})',
            failure: failure,
          ),
        );
      } else {
        imported++;
      }
    }
    return ImportOutcome(
      kind: ImportKind.customers,
      imported: imported,
      failures: failures,
    );
  }

  Future<ImportOutcome> _commitParts(String branchId) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final failures = <ImportWriteFailure>[];
    var imported = 0;
    for (final row in _parts) {
      final result = await repo.createPart(
        Part(
          id: '',
          category: row.category,
          reference: row.reference,
          binCode: row.binCode,
          onHand: row.onHand,
          reserved: 0,
          minLevel: row.minLevel,
          reorderPoint: row.reorderPoint,
          serviceOnly: row.serviceOnly,
          costPaise: row.costPaise,
          mrpPaise: row.mrpPaise,
          branchId: branchId,
          size: row.size,
        ),
        by: _uid,
      );
      final failure = result.failureOrNull;
      if (failure != null) {
        failures.add(
          ImportWriteFailure(label: row.reference, failure: failure),
        );
      } else {
        imported++;
      }
    }
    return ImportOutcome(
      kind: ImportKind.parts,
      imported: imported,
      failures: failures,
    );
  }
}

/// The import controller provider.
final importControllerProvider =
    AutoDisposeNotifierProvider<ImportController, ImportUiState>(
  ImportController.new,
);
