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
  String get signOut => 'Sign out';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsEmptyTitle => 'No sessions yet';

  @override
  String get sessionsEmptyBody =>
      'Create one for tonight, then paste your signup list.';

  @override
  String get newSession => 'New session';

  @override
  String get pendingSync =>
      'Saved on this device — will sync when you\'re back online';

  @override
  String get sessionStatusSetup => 'Setup';

  @override
  String get sessionStatusLive => 'Live';

  @override
  String get sessionStatusEnded => 'Ended';

  @override
  String courtCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courts',
      one: '1 court',
    );
    return '$_temp0';
  }

  @override
  String get newSessionTitle => 'New session';

  @override
  String get editSessionTitle => 'Edit session';

  @override
  String get sessionNameLabel => 'Session name';

  @override
  String get sessionNameHint => 'Monday Night Palo';

  @override
  String get venueLabel => 'Venue';

  @override
  String get venueHint => 'Yspacio, Alapan, Imus';

  @override
  String get dateLabel => 'Date';

  @override
  String get courtsLabel => 'Courts';

  @override
  String get courtFeeLabel => 'Court fee for the night';

  @override
  String get shuttlePriceLabel => 'Price per shuttlecock';

  @override
  String get feeModeLabel => 'How to split the cost';

  @override
  String get feeModePerHead => 'Per head';

  @override
  String get feeModePerHeadHelp =>
      'Court fee is split evenly; each player pays for their own shuttles.';

  @override
  String get feeModeAmerican => 'American';

  @override
  String get feeModeAmericanHelp =>
      'Everything is pooled — court and shuttles — then split evenly.';

  @override
  String get createSessionButton => 'Create session';

  @override
  String get saveChangesButton => 'Save changes';

  @override
  String get errSessionNameRequired =>
      'Give tonight a name so you can find it later';

  @override
  String get errVenueRequired => 'Where are you playing?';

  @override
  String get errCourtsRange => 'Enter between 1 and 12 courts';

  @override
  String get errFeeInvalid => 'Enter a valid amount, like 1200 or 1200.50';

  @override
  String get deleteSession => 'Delete session';

  @override
  String deleteSessionConfirm(String title) {
    return 'Delete \"$title\" and everything in it? Players, matches and fees for this night will be permanently removed.';
  }

  @override
  String get deleteSessionCta => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get sessionDeleted => 'Session deleted';

  @override
  String get openSession => 'Open';

  @override
  String get rosterComingSoon => 'Roster and courts arrive in the next step.';
}
