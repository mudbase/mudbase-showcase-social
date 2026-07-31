import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mudbase_exception.dart';
import 'auth_controller.dart';

/// Self-signup is always the `customer` role - there is only one
/// application role in this app (see `plan/build-plan.md`). This project
/// requires email verification (confirmed live by the reference web app):
/// `register()` returns `201` with no session token, so this screen shows a
/// "check your inbox" success state rather than assuming sign-in happened,
/// matching `AuthController.registerCustomer`'s handling exactly.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreedToTerms = false;
  bool _submitting = false;
  bool _registered = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please agree to the terms to continue.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerCustomer(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            agreedToTerms: _agreedToTerms,
          );
      if (mounted) setState(() => _registered = true);
    } on MudbaseException catch (error) {
      setState(() => _errorMessage = error.message);
    } on FormatException {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _registered
                  ? _CheckInboxNotice(email: _emailController.text.trim())
                  : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Email is required';
              if (!trimmed.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Use at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreedToTerms,
            onChanged: (value) =>
                setState(() => _agreedToTerms = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I agree to the terms of service'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInboxNotice extends StatelessWidget {
  const _CheckInboxNotice({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'Check your inbox',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a verification link to $email. Follow it, then come back '
          'here and sign in.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Go to sign in'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
