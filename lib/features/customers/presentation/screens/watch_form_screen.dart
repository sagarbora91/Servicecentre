import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../domain/entities/watch.dart';
import '../controllers/customer_write_controller.dart';

/// Add/edit watch form for a customer. Pushed from the customer detail screen.
class WatchFormScreen extends ConsumerStatefulWidget {
  /// Creates the form for [customerId]. [existing] is the watch being edited,
  /// or `null` to add a new one.
  const WatchFormScreen({required this.customerId, this.existing, super.key});

  /// The owning customer.
  final String customerId;

  /// The watch being edited, or `null` when adding.
  final Watch? existing;

  @override
  ConsumerState<WatchFormScreen> createState() => _WatchFormScreenState();
}

class _WatchFormScreenState extends ConsumerState<WatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serial;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _brand = TextEditingController(text: e?.brand ?? '');
    _model = TextEditingController(text: e?.model ?? '');
    _serial = TextEditingController(text: e?.serial ?? '');
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(customerWriteControllerProvider.notifier);
    final serial = _serial.text.trim();
    final existing = widget.existing;
    final failure = existing == null
        ? await controller.addWatch(
            customerId: widget.customerId,
            brand: _brand.text.trim(),
            model: _model.text.trim(),
            serial: serial.isEmpty ? null : serial,
          )
        : await controller.updateWatch(
            existing.id,
            brand: _brand.text.trim(),
            model: _model.text.trim(),
            serial: serial.isEmpty ? null : serial,
          );
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
    final isLoading = ref.watch(customerWriteControllerProvider).isLoading;

    return Scaffold(
      key: const Key('watchFormScreen'),
      appBar: AppBar(
        title:
            Text(_isEditing ? l10n.watchFormEditTitle : l10n.watchFormAddTitle),
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
                    key: const Key('watchBrandField'),
                    controller: _brand,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.watchBrandLabel,
                      prefixIcon: const Icon(Icons.watch_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.watchBrandRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('watchModelField'),
                    controller: _model,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.watchModelLabel,
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.watchModelRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('watchSerialField'),
                    controller: _serial,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.watchSerialLabel,
                      prefixIcon: const Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('saveWatchBtn'),
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
