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
  String get m0ScaffoldReady => 'Scaffold ready';

  @override
  String m0FirebaseConnected(String projectId) {
    return 'Firebase project: $projectId';
  }

  @override
  String get m0FirebaseNotInitialized => 'Firebase not initialized';

  @override
  String get m0OfflinePersistence => 'Offline persistence: unlimited cache';

  @override
  String get m0NextMilestone => 'Next up: M1 — Queue Master sign-in';
}
