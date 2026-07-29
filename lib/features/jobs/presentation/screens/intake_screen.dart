import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../auth/presentation/auth_guard.dart';
import '../../../auth/presentation/providers/staff_providers.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/entities/watch.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../controllers/intake_controller.dart';

/// New-job intake (`/jobs/new`, any active staff). Links an existing customer
/// (and optionally one of their watches), captures the fault/work/turnaround,
/// then creates the job — which lands in the board's `received` column.
///
/// Customer selection is a dropdown for M3; the searchable picker + inline
/// customer creation arrive with the Customers UI in M4.
class IntakeScreen extends ConsumerStatefulWidget {
  /// Creates the intake screen.
  const IntakeScreen({super.key});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _faultController = TextEditingController();
  final _workController = TextEditingController();
  final _tatController = TextEditingController(text: '48');
  String? _customerId;
  String? _watchId;

  @override
  void dispose() {
    _faultController.dispose();
    _workController.dispose();
    _tatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (!_formKey.currentState!.validate()) return;

    final result = await ref.read(intakeControllerProvider.notifier).create(
          customerId: _customerId!,
          fault: _faultController.text.trim(),
          workRequested: _workController.text.trim(),
          tatTargetHrs: int.parse(_tatController.text.trim()),
          watchId: _watchId,
        );
    if (!mounted) return;
    if (result.isErr) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.jobCreated)));
    router.go(Routes.board);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      key: const Key('intakeScreen'),
      appBar: AppBar(
        title: Text(l10n.jobIntakeTitle),
        leading: IconButton(
          key: const Key('intakeBack'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.board),
        ),
      ),
      body: branchId == null
          ? _Centered(
              key: const Key('intakeNoBranch'),
              message: l10n.branchNotConfigured,
            )
          : _form(l10n, branchId),
    );
  }

  Widget _form(AppLocalizations l10n, String branchId) {
    final isLoading = ref.watch(intakeControllerProvider).isLoading;
    final customers = ref.watch(customersProvider(branchId)).valueOrNull ??
        const <Customer>[];
    final watches = _customerId == null
        ? const <Watch>[]
        : (ref.watch(customerWatchesProvider(_customerId!)).valueOrNull ??
            const <Watch>[]);

    if (customers.isEmpty) {
      return _Centered(
        key: const Key('intakeNoCustomers'),
        message: l10n.intakeNoCustomers,
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('customerDropdown'),
                  initialValue: _customerId,
                  decoration: InputDecoration(
                    labelText: l10n.intakeCustomerLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  items: [
                    for (final c in customers)
                      DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name.trim().isEmpty ? c.phone : c.name),
                      ),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() {
                            _customerId = value;
                            _watchId = null;
                          }),
                  validator: (value) =>
                      value == null ? l10n.intakeSelectCustomer : null,
                ),
                const SizedBox(height: 16),
                if (_customerId != null) ...[
                  DropdownButtonFormField<String?>(
                    key: const Key('watchDropdown'),
                    initialValue: _watchId,
                    decoration: InputDecoration(
                      labelText: l10n.intakeWatchLabel,
                      prefixIcon: const Icon(Icons.watch_outlined),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        child: Text(l10n.intakeWatchNone),
                      ),
                      for (final w in watches)
                        DropdownMenuItem<String?>(
                          value: w.id,
                          child: Text('${w.brand} ${w.model}'.trim()),
                        ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) => setState(() => _watchId = value),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('faultField'),
                  controller: _faultController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: l10n.intakeFaultLabel,
                    prefixIcon: const Icon(Icons.report_problem_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.intakeFaultRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('workField'),
                  controller: _workController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: l10n.intakeWorkLabel,
                    prefixIcon: const Icon(Icons.build_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.intakeWorkRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('tatField'),
                  controller: _tatController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.intakeTatLabel,
                    prefixIcon: const Icon(Icons.schedule_outlined),
                  ),
                  validator: (value) {
                    final hours = int.tryParse(value?.trim() ?? '');
                    return (hours == null || hours <= 0)
                        ? l10n.intakeTatInvalid
                        : null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('saveJobBtn'),
                  onPressed: isLoading ? null : () => unawaited(_submit()),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.saveButton),
                ),
              ],
            ),
          ),
        ),
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
