import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../controllers/manage_staff_controller.dart';
import 'role_home_screen.dart' show roleLabel;

/// Add/edit form for a staff member, owner-only. Pushed on top of
/// [ManageStaffScreen] (which is itself behind the owner route guard), so it
/// inherits that gate; the real enforcement stays in `firestore.rules`.
///
/// Pass [existing] to edit (its uid is fixed and shown read-only) or leave it
/// `null` to create. On create the owner supplies the staff member's existing
/// sign-in account id (uid) — minting new logins lands with the `setUserRole`
/// function in M8; until then accounts are provisioned out-of-band.
class StaffFormScreen extends ConsumerStatefulWidget {
  /// Creates the staff form. [branchId] is the owner's branch, stamped onto new
  /// staff. [existing] is the member being edited, or `null` to create.
  const StaffFormScreen({
    required this.branchId,
    this.existing,
    super.key,
  });

  /// The branch new staff are created in (the owner's branch).
  final String branchId;

  /// The staff member being edited, or `null` when creating a new one.
  final AppUser? existing;

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _uidController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late UserRole _role;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _uidController = TextEditingController(text: existing?.uid ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _role = existing?.role ?? UserRole.counter;
  }

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existing;
    final email = _emailController.text.trim();
    final user = AppUser(
      uid: existing?.uid ?? _uidController.text.trim(),
      name: _nameController.text.trim(),
      role: _role,
      phone: _phoneController.text.trim(),
      // Preserve active on edit; new staff start active. The active flag is
      // toggled from the list, never silently flipped by a profile save.
      active: existing?.active ?? true,
      email: email.isEmpty ? null : email,
      branchId: existing?.branchId ?? widget.branchId,
    );

    final failure =
        await ref.read(manageStaffControllerProvider.notifier).save(user);
    if (!mounted) return;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      return;
    }
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(manageStaffControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editStaff : l10n.addStaff),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('staffUidField'),
                    controller: _uidController,
                    enabled: !_isEditing && !isLoading,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.staffUidLabel,
                      helperText: l10n.staffUidHelper,
                      helperMaxLines: 3,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.uidRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('staffNameField'),
                    controller: _nameController,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.staffNameLabel,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.nameRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('staffPhoneField'),
                    controller: _phoneController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.staffPhoneLabel,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.phoneRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('staffEmailField'),
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.staffEmailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    key: const Key('staffRoleDropdown'),
                    initialValue: _role,
                    decoration: InputDecoration(
                      labelText: l10n.staffRoleLabel,
                      prefixIcon: const Icon(Icons.security_outlined),
                    ),
                    items: [
                      for (final role in UserRole.values)
                        DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(roleLabel(role, l10n)),
                        ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (role) {
                            if (role != null) setState(() => _role = role);
                          },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('saveStaffBtn'),
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
