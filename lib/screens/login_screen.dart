import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../services/account_security.dart';
import '../services/auth_error_mapper.dart';
import '../widgets/shuttle_mark.dart';
import '../theme.dart';

/// Email/password sign-in at registration sa iisang screen.
/// Walang navigation pagkatapos mag-login — ang AuthGate na ang
/// magpapalit ng screen kapag nag-emit ang authStateChanges.
///
/// Sinusunod nito ang sign-in form best practices ng web.dev hangga't
/// kaya ng Flutter. Ang mahalaga roon:
///
///   * autofill — `AutofillGroup` at `autofillHints` ang nagpapalabas ng
///     `autocomplete="username"` at `current-password` sa DOM, kaya
///     gumagana ang password manager ng browser. Ito ang pinakamalaking
///     panalo: kapag naaalala ng manager ang password, mahaba ito at
///     natatangi sa halip na `sana all123`.
///   * isang password field lang — kailanman ay hindi dalawang beses.
///   * puwedeng i-paste — hindi hinaharangan.
///   * "Nakalimutan ang password" — nariyan at nakikita.
///   * inaanunsiyo ang error (liveRegion) at may babala ang show-password.
///
/// Hindi lahat ay kayang ilipat: ang Flutter web ay gumuguhit sa canvas,
/// kaya walang tunay na `<label for>` o `:invalid` na CSS. Ang inaabot
/// natin ay ang layunin ng bawat tuntunin, hindi ang mismong markup.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  var _isRegistering = false;
  var _isSubmitting = false;
  var _obscurePassword = true;
  String? _errorText;
  String? _noticeText;

  /// Panandaliang pagpapabagal pagkatapos ng sunod-sunod na palya.
  var _failedAttempts = 0;
  Duration _lockRemaining = Duration.zero;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    // Ang password strength meter ay kailangang gumalaw habang nagta-type.
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (_isRegistering) setState(() {});
  }

  bool get _isLocked => _lockRemaining > Duration.zero;

  void _startLockCountdown(Duration total) {
    _lockTimer?.cancel();
    setState(() => _lockRemaining = total);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final next = _lockRemaining - const Duration(seconds: 1);
      setState(() => _lockRemaining = next.isNegative ? Duration.zero : next);
      if (_lockRemaining == Duration.zero) timer.cancel();
    });
  }

  /// Client-side validation muna bago tumawag sa Firebase — mas mabilis
  /// ang feedback at hindi nasasayang ang network round-trip.
  String? _validate(AppLocalizations l10n) {
    if (_isRegistering && _nameController.text.trim().isEmpty) {
      return l10n.errNameRequired;
    }
    final email = _emailController.text;
    if (email.trim().isEmpty) return l10n.errEmailRequired;
    if (!looksLikeEmail(email)) return l10n.errInvalidEmail;

    // Sa PAGGAWA lang ng account ang mas mahabang minimum. Ang mga lumang
    // account ay dapat pa ring makapasok (tingnan ang account_security.dart).
    if (_isRegistering) {
      if (ratePassword(_passwordController.text) == PasswordStrength.tooShort) {
        return l10n.errPasswordTooShort;
      }
    } else if (_passwordController.text.isEmpty) {
      return l10n.errPasswordRequired;
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
    if (_isSubmitting || _isLocked) return;

    final l10n = AppLocalizations.of(context)!;
    final validationError = _validate(l10n);
    if (validationError != null) {
      setState(() {
        _errorText = validationError;
        _noticeText = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _noticeText = null;
    });

    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isRegistering) {
        await repo.register(
          displayName: _nameController.text.trim(),
          email: normalizeEmail(_emailController.text),
          password: _passwordController.text,
        );
      } else {
        await repo.signIn(
          email: normalizeEmail(_emailController.text),
          password: _passwordController.text,
        );
      }
      _failedAttempts = 0;
      // Walang Navigator.push dito — ang AuthGate ang bahala.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final mapped = mapAuthErrorCode(e.code);
      // Ang maling password lang ang binibilang. Ang walang signal ay
      // hindi panghuhula, at hindi dapat ma-lock ang QM dahil doon.
      if (mapped == AuthError.invalidCredentials) _failedAttempts++;
      setState(() => _errorText = _messageFor(mapped, l10n));

      final lock = signInLockout(_failedAttempts);
      if (lock > Duration.zero) _startLockCountdown(lock);
    } catch (_) {
      if (mounted) setState(() => _errorText = l10n.errUnknown);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Nagpapadala ng reset link. Pareho ang sagot kahit walang ganoong
  /// account — kung hindi, ang page na ito ay nagiging tseker kung sino
  /// ang may account (email enumeration).
  Future<void> _sendReset() async {
    final l10n = AppLocalizations.of(context)!;
    if (!looksLikeEmail(_emailController.text)) {
      setState(() {
        _errorText = l10n.errEmailForReset;
        _noticeText = null;
      });
      _emailFocus.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _noticeText = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(normalizeEmail(_emailController.text));
    } catch (_) {
      // Sinasadyang nilulunok. Ang "walang ganyang account" ay isang
      // sagot na hindi natin ibinibigay.
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _noticeText = l10n.resetLinkSent;
        });
      }
    }
  }

  void _switchMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _errorText = null;
      _noticeText = null;
      _passwordController.clear();
    });
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
              // Ang AutofillGroup ang nagsasabi sa browser na iisang form
              // ito. Kung wala ito, hindi maiaalok ng password manager na
              // i-save ang bagong password.
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ShuttleMark(size: 68)),
                    const SizedBox(height: 14),
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge,
                    ),
                    Text(
                      _isRegistering ? l10n.registerTagline : l10n.loginTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: context.sq.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isRegistering) ...[
                      TextField(
                        controller: _nameController,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(
                          labelText: l10n.displayNameLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      // username + email: ito ang hinahanap ng mga password
                      // manager para maiugnay ang naka-save na kredensyal.
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      // Ang pagkakaiba ng bago at kasalukuyan ang nagsasabi
                      // sa manager kung mag-aalok ba ng naka-save o
                      // magmumungkahi ng bagong matibay.
                      autofillHints: [
                        if (_isRegistering)
                          AutofillHints.newPassword
                        else
                          AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText:
                            _isRegistering ? l10n.passwordHint : null,
                        suffixIcon: Semantics(
                          // Babala sa loob mismo ng label, gaya ng
                          // rekomendasyon: baka may nakatingin sa likod.
                          label: _obscurePassword
                              ? l10n.showPasswordWarning
                              : l10n.hidePassword,
                          button: true,
                          child: IconButton(
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
                      ),
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_isRegistering &&
                        _passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _StrengthMeter(
                        strength: ratePassword(_passwordController.text),
                      ),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      // liveRegion: inaanunsiyo ito ng screen reader kahit
                      // hindi nakatutok ang cursor dito.
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_noticeText != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _noticeText!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      // 52 ang taas: lampas sa 44x48 na minimum para sa
                      // hinlalaki ng taong nakatayo sa gilid ng court.
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: (_isSubmitting || _isLocked) ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(
                              _isLocked
                                  ? l10n.tryAgainIn(_lockRemaining.inSeconds)
                                  : _isRegistering
                                      ? l10n.registerButton
                                      : l10n.signInButton,
                            ),
                    ),
                    // Dalawang berdeng link na magkasinglakas ay nagiging
                    // dalawang panukala. Ang "nakalimutan ko" ay tahimik —
                    // hinahanap mo lang ito kapag kailangan; ang paglipat ng
                    // mode ay siyang totoong pangalawang daan.
                    if (!_isRegistering) ...[
                      const SizedBox(height: SQSpace.xs),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: context.sq.inkMuted,
                          textStyle: theme.textTheme.bodyMedium,
                        ),
                        onPressed: _isSubmitting ? null : _sendReset,
                        child: Text(l10n.forgotPassword),
                      ),
                    ],
                    const SizedBox(height: SQSpace.xs),
                    TextButton(
                      onPressed: _isSubmitting ? null : _switchMode,
                      child: Text(
                        _isRegistering
                            ? l10n.switchToSignIn
                            : l10n.switchToRegister,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // RA 10173: sinasabi natin nang maaga kung ano ang
                    // itinatago, bago pa may maitala.
                    Text(
                      l10n.privacyNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.sq.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Para kapag may isinumbong na problema, masasagot ang
                    // unang tanong: anong bersyon ba ang hawak mo?
                    Text(
                      'v$kAppVersion',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.sq.inkFaint.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tatlong maliit na bar — pakiramdam, hindi marka.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final (int filled, String label, Color color) = switch (strength) {
      PasswordStrength.tooShort => (0, l10n.strengthTooShort, scheme.error),
      PasswordStrength.weak => (1, l10n.strengthWeak, scheme.error),
      PasswordStrength.fair => (2, l10n.strengthFair, scheme.tertiary),
      PasswordStrength.strong => (3, l10n.strengthStrong, scheme.primary),
    };

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < filled
                    ? color
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
