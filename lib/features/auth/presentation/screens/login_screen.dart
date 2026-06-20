import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n/app_localizations.dart';
import '../../../../core/errors/failure.dart';
import '../controllers/sign_in_controller.dart';

/// Email/password sign-in screen (M1). Phone OTP is added later once a live
/// Firebase project exists.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final failure = await ref.read(signInControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _errorMessage = _messageFor(failure, l10n));
    }
  }

  String _messageFor(Failure failure, AppLocalizations l10n) {
    if (failure is AuthFailure) {
      return switch (failure.reason) {
        AuthFailureReason.invalidCredentials =>
          l10n.authErrorInvalidCredentials,
        AuthFailureReason.userDisabled => l10n.authErrorUserDisabled,
        AuthFailureReason.network => l10n.authErrorNetwork,
        AuthFailureReason.tooManyRequests => l10n.authErrorTooManyRequests,
        AuthFailureReason.unknown => l10n.authErrorUnknown,
      };
    }
    return l10n.authErrorUnknown;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(signInControllerProvider).isLoading;
    final errorMessage = _errorMessage;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
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
                  const Icon(Icons.watch_outlined, size: 56),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('emailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) => _validateEmail(value, l10n),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('passwordField'),
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty)
                            ? l10n.passwordRequired
                            : null,
                    onFieldSubmitted: (_) => unawaited(_submit()),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      key: const Key('signInError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('signInBtn'),
                    onPressed: isLoading ? null : () => unawaited(_submit()),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.signInButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value, AppLocalizations l10n) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l10n.emailRequired;
    if (!email.contains('@') || !email.contains('.')) return l10n.emailInvalid;
    return null;
  }
}
