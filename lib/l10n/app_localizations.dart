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

  /// No description provided for @tabRoster.
  ///
  /// In en, this message translates to:
  /// **'Roster'**
  String get tabRoster;

  /// No description provided for @tabCourts.
  ///
  /// In en, this message translates to:
  /// **'Courts'**
  String get tabCourts;

  /// No description provided for @tabMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get tabMoney;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste your signup list'**
  String get importTitle;

  /// No description provided for @importInstructions.
  ///
  /// In en, this message translates to:
  /// **'Copy the numbered list from your group chat and paste it here. We\'ll clean it up — you can fix anything before it\'s saved.'**
  String get importInstructions;

  /// No description provided for @importHint.
  ///
  /// In en, this message translates to:
  /// **'1. Jun\n2. Ana\n3. Mark +1'**
  String get importHint;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get importPreview;

  /// No description provided for @importFoundPlayers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No names found yet} =1{1 player} other{{count} players}}'**
  String importFoundPlayers(int count);

  /// No description provided for @importSkippedLines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line skipped} other{{count} lines skipped}}'**
  String importSkippedLines(int count);

  /// No description provided for @importSkippedExplain.
  ///
  /// In en, this message translates to:
  /// **'These looked like headers or chatter. Tap to add one as a player if we got it wrong.'**
  String get importSkippedExplain;

  /// No description provided for @importDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 name appears twice} other{{count} names appear twice}} — check if they\'re the same person or two different players.'**
  String importDuplicateWarning(int count);

  /// No description provided for @importGuestBadge.
  ///
  /// In en, this message translates to:
  /// **'guest'**
  String get importGuestBadge;

  /// No description provided for @importAddAll.
  ///
  /// In en, this message translates to:
  /// **'Add to roster'**
  String get importAddAll;

  /// No description provided for @importConsent.
  ///
  /// In en, this message translates to:
  /// **'Names only. No phone numbers or emails are stored, and deleting the session removes everything.'**
  String get importConsent;

  /// No description provided for @importEmpty.
  ///
  /// In en, this message translates to:
  /// **'Paste a list above to get started.'**
  String get importEmpty;

  /// No description provided for @rosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Roster'**
  String get rosterTitle;

  /// No description provided for @rosterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No players yet'**
  String get rosterEmptyTitle;

  /// No description provided for @rosterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Paste your signup list, or add players one by one.'**
  String get rosterEmptyBody;

  /// No description provided for @pasteList.
  ///
  /// In en, this message translates to:
  /// **'Paste list'**
  String get pasteList;

  /// No description provided for @addPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add player'**
  String get addPlayer;

  /// No description provided for @addPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add player'**
  String get addPlayerTitle;

  /// No description provided for @playerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playerNameLabel;

  /// No description provided for @editPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit player'**
  String get editPlayerTitle;

  /// No description provided for @skillLabel.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get skillLabel;

  /// No description provided for @skillBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get skillBeginner;

  /// No description provided for @skillIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get skillIntermediate;

  /// No description provided for @skillAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get skillAdvanced;

  /// No description provided for @statusQueued.
  ///
  /// In en, this message translates to:
  /// **'In queue'**
  String get statusQueued;

  /// No description provided for @statusPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get statusPlaying;

  /// No description provided for @statusResting.
  ///
  /// In en, this message translates to:
  /// **'Resting'**
  String get statusResting;

  /// No description provided for @statusLeft.
  ///
  /// In en, this message translates to:
  /// **'Left early'**
  String get statusLeft;

  /// No description provided for @markResting.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get markResting;

  /// No description provided for @markQueued.
  ///
  /// In en, this message translates to:
  /// **'Back in queue'**
  String get markQueued;

  /// No description provided for @markLeft.
  ///
  /// In en, this message translates to:
  /// **'Mark as left'**
  String get markLeft;

  /// No description provided for @removePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePlayer;

  /// No description provided for @playerRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String playerRemoved(String name);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @gamesPlayedShort.
  ///
  /// In en, this message translates to:
  /// **'{count} games'**
  String gamesPlayedShort(int count);

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @rosterCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} players · {queued} in queue'**
  String rosterCountSummary(int total, int queued);
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
