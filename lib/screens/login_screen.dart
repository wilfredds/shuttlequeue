import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../services/auth_error_mapper.dart';

/// Email/password sign-in at registration sa iisang screen.
/// Walang navigation pagkatapos mag-login — ang AuthGate na ang
/// magpapalit ng screen kapag nag-emit ang authStateChanges.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  var _isRegistering = false;
  var _isSubmitting = false;
  var _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Client-side validation muna bago tumawag sa Firebase — mas mabilis
  /// ang feedback at hindi nasasayang ang network round-trip.
  String? _validate(AppLocalizations l10n) {
    if (_isRegistering && _nameController.text.trim().isEmpty) {
      return l10n.errNameRequired;
    }
    if (_emailController.text.trim().isEmpty) {
      return l10n.errEmailRequired;
    }
    if (_passwordController.text.length < 6) {
      return l10n.errPasswordTooShort;
    }
    return null;
  }

  String _messageFor(AuthError error, AppLocalizations l10n) {
    switch (error) {
      case AuthError.invalidCredentials:
        return l10n.errInvalidCredentials;
      case AuthError.emailAlreadyInUse:
        return l10n.errEmailAlreadyInUse;
      case AuthError.weakPassword:
        return l10n.errWeakPassword;
      case AuthError.invalidEmail:
        return l10n.errInvalidEmail;
      case AuthError.network:
        return l10n.errNetwork;
      case AuthError.tooManyRequests:
        return l10n.errTooManyRequests;
      case AuthError.unknown:
        return l10n.errUnknown;
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    final validationError = _validate(l10n);
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isRegistering) {
        await repo.register(
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await repo.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      // Walang Navigator.push dito — ang AuthGate ang bahala.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorText = _messageFor(mapAuthErrorCode(e.code), l10n));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = l10n.errUnknown);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sports_tennis,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge,
                  ),
                  Text(
                    l10n.loginTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isRegistering) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.displayNameLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? l10n.showPassword
                            : l10n.hidePassword,
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _isSubmitting ? null : _submit(),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            _isRegistering
                                ? l10n.registerButton
                                : l10n.signInButton,
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                              _isRegistering = !_isRegistering;
                              _errorText = null;
                            }),
                    child: Text(
                      _isRegistering
                          ? l10n.switchToSignIn
                          : l10n.switchToRegister,
                    ),
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
