import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customer_write_controller.dart';

/// Add/edit customer form. Pushed from the list FAB (create) or the detail edit
/// action (edit). On create, the repository enforces phone de-dupe and the
/// resulting [ConflictFailure] is shown.
class CustomerFormScreen extends ConsumerStatefulWidget {
  /// Creates the form. [existing] is the customer being edited, or `null` to
  /// create a new one.
  const CustomerFormScreen({this.existing, super.key});

  /// The customer being edited, or `null` when creating.
  final Customer? existing;

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late bool _consent;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _consent = e?.consentWhatsApp ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  String _message(Failure failure, AppLocalizations l10n) =>
      failure is ConflictFailure ? l10n.customerPhoneExists : l10n.saveFailed;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(customerWriteControllerProvider.notifier);
    final email = _email.text.trim();
    final address = _address.text.trim();
    final existing = widget.existing;
    final failure = existing == null
        ? await controller.createCustomer(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: email.isEmpty ? null : email,
            address: address.isEmpty ? null : address,
            consentWhatsApp: _consent,
          )
        : await controller.updateCustomer(
            existing.id,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: email.isEmpty ? null : email,
            address: address.isEmpty ? null : address,
            consentWhatsApp: _consent,
          );
    if (!mounted) return;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(_message(failure, l10n))));
      return;
    }
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(customerWriteControllerProvider).isLoading;

    return Scaffold(
      key: const Key('customerFormScreen'),
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editCustomer : l10n.addCustomer),
      ),
      body: Center(
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
                  TextFormField(
                    key: const Key('customerNameField'),
                    controller: _name,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.customerNameLabel,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.customerNameRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerPhoneField'),
                    controller: _phone,
                    enabled: !isLoading,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.customerPhoneLabel,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.customerPhoneRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerEmailField'),
                    controller: _email,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.customerEmailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customerAddressField'),
                    controller: _address,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.customerAddressLabel,
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('customerConsentSwitch'),
                    title: Text(l10n.customerConsentLabel),
                    value: _consent,
                    onChanged: isLoading
                        ? null
                        : (v) => setState(() => _consent = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('saveCustomerBtn'),
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
      ),
    );
  }
}
