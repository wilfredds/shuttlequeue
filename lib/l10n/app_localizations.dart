import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application name, shown in the app bar and task switcher
  ///
  /// In en, this message translates to:
  /// **'ShuttleQueue'**
  String get appTitle;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Queue Master sign-in'**
  String get loginTagline;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get displayNameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerButton;

  /// No description provided for @switchToRegister.
  ///
  /// In en, this message translates to:
  /// **'New Queue Master? Create an account'**
  String get switchToRegister;

  /// No description provided for @switchToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get switchToSignIn;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get errNameRequired;

  /// No description provided for @errEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get errEmailRequired;

  /// No description provided for @errPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get errPasswordTooShort;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'That email already has an account — try signing in'**
  String get errEmailAlreadyInUse;

  /// No description provided for @errWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please use a stronger password (at least 6 characters)'**
  String get errWeakPassword;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid email'**
  String get errInvalidEmail;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection — signing in for the first time needs internet'**
  String get errNetwork;

  /// No description provided for @errTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — wait a minute and try again'**
  String get errTooManyRequests;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — please try again'**
  String get errUnknown;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionsEmptyTitle;

  /// No description provided for @sessionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create one for tonight, then paste your signup list.'**
  String get sessionsEmptyBody;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device — will sync when you\'re back online'**
  String get pendingSync;

  /// No description provided for @sessionStatusSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get sessionStatusSetup;

  /// No description provided for @sessionStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get sessionStatusLive;

  /// No description provided for @sessionStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get sessionStatusEnded;

  /// No description provided for @courtCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 court} other{{count} courts}}'**
  String courtCountLabel(int count);

  /// No description provided for @newSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSessionTitle;

  /// No description provided for @editSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get editSessionTitle;

  /// No description provided for @sessionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get sessionNameLabel;

  /// No description provided for @sessionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Monday Night Palo'**
  String get sessionNameHint;

  /// No description provided for @venueLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get venueLabel;

  /// No description provided for @venueHint.
  ///
  /// In en, this message translates to:
  /// **'Yspacio, Alapan, Imus'**
  String get venueHint;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @courtsLabel.
  ///
  /// In en, this message translates to:
  /// **'Courts'**
  String get courtsLabel;

  /// No description provided for @courtFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Court fee for the night'**
  String get courtFeeLabel;

  /// No description provided for @shuttlePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per shuttlecock'**
  String get shuttlePriceLabel;

  /// No description provided for @feeModeLabel.
  ///
  /// In en, this message translates to:
  /// **'How to split the cost'**
  String get feeModeLabel;

  /// No description provided for @feeModePerHead.
  ///
  /// In en, this message translates to:
  /// **'Per head'**
  String get feeModePerHead;

  /// No description provided for @feeModePerHeadHelp.
  ///
  /// In en, this message translates to:
  /// **'Court fee is split evenly; each player pays for their own shuttles.'**
  String get feeModePerHeadHelp;

  /// No description provided for @feeModeAmerican.
  ///
  /// In en, this message translates to:
  /// **'American'**
  String get feeModeAmerican;

  /// No description provided for @feeModeAmericanHelp.
  ///
  /// In en, this message translates to:
  /// **'Everything is pooled — court and shuttles — then split evenly.'**
  String get feeModeAmericanHelp;

  /// No description provided for @createSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Create session'**
  String get createSessionButton;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChangesButton;

  /// No description provided for @errSessionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give tonight a name so you can find it later'**
  String get errSessionNameRequired;

  /// No description provided for @errVenueRequired.
  ///
  /// In en, this message translates to:
  /// **'Where are you playing?'**
  String get errVenueRequired;

  /// No description provided for @errCourtsRange.
  ///
  /// In en, this message translates to:
  /// **'Enter between 1 and 12 courts'**
  String get errCourtsRange;

  /// No description provided for @errFeeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount, like 1200 or 1200.50'**
  String get errFeeInvalid;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get deleteSession;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" and everything in it? Players, matches and fees for this night will be permanently removed.'**
  String deleteSessionConfirm(String title);

  /// No description provided for @deleteSessionCta.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSessionCta;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @sessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionDeleted;

  /// No description provided for @openSession.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openSession;

  /// No description provided for @rosterComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Roster and courts arrive in the next step.'**
  String get rosterComingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
