// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ShuttleQueue';

  @override
  String get loginTagline => 'Queue Master sign-in';

  @override
  String get displayNameLabel => 'Your name';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get registerButton => 'Create account';

  @override
  String get switchToRegister => 'New Queue Master? Create an account';

  @override
  String get switchToSignIn => 'Already have an account? Sign in';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get errNameRequired => 'Please enter your name';

  @override
  String get errEmailRequired => 'Please enter your email';

  @override
  String get errPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get errInvalidCredentials => 'Email or password is incorrect';

  @override
  String get errEmailAlreadyInUse =>
      'That email already has an account — try signing in';

  @override
  String get errWeakPassword =>
      'Please use a stronger password (at least 6 characters)';

  @override
  String get errInvalidEmail => 'That doesn\'t look like a valid email';

  @override
  String get errNetwork =>
      'No connection — signing in for the first time needs internet';

  @override
  String get errTooManyRequests =>
      'Too many attempts — wait a minute and try again';

  @override
  String get errUnknown => 'Something went wrong — please try again';

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get sessionsComingSoon => 'Your sessions will appear here (M2)';
}
