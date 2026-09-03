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

  @override
  String get tabRoster => 'Roster';

  @override
  String get tabCourts => 'Courts';

  @override
  String get tabMoney => 'Money';

  @override
  String get importTitle => 'Paste your signup list';

  @override
  String get importInstructions =>
      'Copy the numbered list from your group chat and paste it here. We\'ll clean it up — you can fix anything before it\'s saved.';

  @override
  String get importHint => '1. Jun\n2. Ana\n3. Mark +1';

  @override
  String get importPreview => 'Preview';

  @override
  String importFoundPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players',
      one: '1 player',
      zero: 'No names found yet',
    );
    return '$_temp0';
  }

  @override
  String importSkippedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines skipped',
      one: '1 line skipped',
    );
    return '$_temp0';
  }

  @override
  String get importSkippedExplain =>
      'These looked like headers or chatter. Tap to add one as a player if we got it wrong.';

  @override
  String importDuplicateWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count names appear twice',
      one: '1 name appears twice',
    );
    return '$_temp0 — check if they\'re the same person or two different players.';
  }

  @override
  String get importGuestBadge => 'guest';

  @override
  String get importAddAll => 'Add to roster';

  @override
  String get importConsent =>
      'Names only. No phone numbers or emails are stored, and deleting the session removes everything.';

  @override
  String get importEmpty => 'Paste a list above to get started.';

  @override
  String get rosterTitle => 'Roster';

  @override
  String get rosterEmptyTitle => 'No players yet';

  @override
  String get rosterEmptyBody =>
      'Paste your signup list, or add players one by one.';

  @override
  String get pasteList => 'Paste list';

  @override
  String get addPlayer => 'Add player';

  @override
  String get addPlayerTitle => 'Add player';

  @override
  String get playerNameLabel => 'Name';

  @override
  String get editPlayerTitle => 'Edit player';

  @override
  String get skillLabel => 'Skill';

  @override
  String get skillBeginner => 'Beginner';

  @override
  String get skillIntermediate => 'Intermediate';

  @override
  String get skillAdvanced => 'Advanced';

  @override
  String get statusQueued => 'In queue';

  @override
  String get statusPlaying => 'Playing';

  @override
  String get statusResting => 'Resting';

  @override
  String get statusLeft => 'Left early';

  @override
  String get markResting => 'Rest';

  @override
  String get markQueued => 'Back in queue';

  @override
  String get markLeft => 'Mark as left';

  @override
  String get removePlayer => 'Remove';

  @override
  String playerRemoved(String name) {
    return '$name removed';
  }

  @override
  String get undo => 'Undo';

  @override
  String gamesPlayedShort(int count) {
    return '$count games';
  }

  @override
  String get saveButton => 'Save';

  @override
  String rosterCountSummary(int total, int queued) {
    return '$total players · $queued in queue';
  }

  @override
  String get nextMatch => 'Next match';

  @override
  String get courtFree => 'Free';

  @override
  String get upNext => 'Up next';

  @override
  String get upNextEmpty => 'Nobody in the queue yet';

  @override
  String get needFourPlayers => 'Need at least 4 players in the queue';

  @override
  String get allCourtsBusy => 'All courts are playing';

  @override
  String get suggestionTitle => 'Suggested match';

  @override
  String get suggestionMixedSkill =>
      'Mixed skill levels — no even group was available';

  @override
  String suggestionForcedWait(String name) {
    return '$name has been waiting a long time';
  }

  @override
  String get swapPlayer => 'Swap';

  @override
  String get swapTitle => 'Swap in a player';

  @override
  String startMatch(String court) {
    return 'Start on $court';
  }

  @override
  String get endMatch => 'Done';

  @override
  String get matchEnded => 'Match finished';

  @override
  String get cancelMatch => 'Cancel match';

  @override
  String get scoreOptional => 'Score (optional)';

  @override
  String waitingTime(int minutes) {
    return '${minutes}m wait';
  }

  @override
  String get noFreeCourt => 'No free court';

  @override
  String get moneyTitle => 'Cost split';

  @override
  String get moneyEmpty => 'Add players first, then the split appears here.';

  @override
  String get totalCost => 'Total cost';

  @override
  String get collected => 'Collected';

  @override
  String get outstanding => 'Still owed';

  @override
  String paidOf(int paid, int total) {
    return '$paid of $total paid';
  }

  @override
  String get shuttlesLabel => 'Shuttles';

  @override
  String get shareSummary => 'Share summary';

  @override
  String get markPaid => 'Paid';

  @override
  String get leftEarlyTag => 'left early';

  @override
  String shuttleCountShort(int count) {
    return '${count}x';
  }

  @override
  String get importKnownPlayer => 'regular';

  @override
  String get importNewPlayer => 'new';

  @override
  String get importAmbiguous => 'which one?';

  @override
  String importMatchedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regulars recognised — skills remembered',
      one: '1 regular recognised — skill remembered',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get importPickMember => 'Which player is this?';

  @override
  String get importNotThisPerson => 'None of these — add as new';

  @override
  String importSessionsAttended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get regularsTitle => 'Regulars';

  @override
  String get regularsEmpty =>
      'Players you import are remembered here, with their skill tier ready for next time.';

  @override
  String regularsSubtitle(String sessions, String tier) {
    return '$sessions · $tier';
  }

  @override
  String get deleteMember => 'Remove from regulars';

  @override
  String memberDeleted(String name) {
    return '$name removed from regulars';
  }

  @override
  String balanceOwed(String amount) {
    return 'owes $amount';
  }

  @override
  String balanceCredit(String amount) {
    return 'credit $amount';
  }

  @override
  String get saveSnapshot => 'Save a copy of tonight';

  @override
  String get snapshotHint =>
      'Share it to yourself — works with no signal, and survives a dead battery.';

  @override
  String get carryUnpaid => 'Carry unpaid to regulars';

  @override
  String carryUnpaidDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count balances carried forward',
      one: '1 balance carried forward',
    );
    return '$_temp0';
  }

  @override
  String get carryUnpaidNone => 'Nobody unpaid, or they aren\'t regulars yet';

  @override
  String carriedBalance(String amount) {
    return 'brought forward: $amount';
  }

  @override
  String get finalizeBill => 'Lock the amounts';

  @override
  String get billLocked =>
      'Amounts locked — late arrivals won\'t change what anyone owes';

  @override
  String billLockedAt(String time) {
    return 'Locked $time';
  }

  @override
  String get reopenBill => 'Unlock';

  @override
  String get reopenBillTitle => 'Unlock the amounts?';

  @override
  String get reopenBillWarning =>
      'Everyone\'s share will be recalculated. If you\'ve already collected money, the amounts on screen may no longer match what people paid.';

  @override
  String get reopenBillCta => 'Unlock anyway';

  @override
  String get billNotLockedHint =>
      'Amounts still update as players join or leave. Lock them before you start collecting.';

  @override
  String get openBoard => 'Show the board';

  @override
  String get boardUpNext => 'Up next';

  @override
  String get boardNobodyWaiting => 'Nobody waiting';

  @override
  String get boardCourtFree => 'Free';

  @override
  String boardWaitingFor(int minutes) {
    return '${minutes}m';
  }

  @override
  String boardGamesCount(int count) {
    return '$count';
  }

  @override
  String get boardGamesLabel => 'games';

  @override
  String boardPlayersWaiting(int count) {
    return '$count waiting';
  }

  @override
  String get boardExit => 'Close board';

  @override
  String boardMoreWaiting(int count) {
    return '+$count more';
  }

  @override
  String get syncFailed =>
      'That didn\'t save. Check your connection — if it keeps happening, tell France.';

  @override
  String get syncFailedDismiss => 'Dismiss';
}
