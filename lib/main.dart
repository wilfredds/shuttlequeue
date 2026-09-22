import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_check.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerFontLicenses();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Bago pa magamit ang Firestore: doon nakakabit ang App Check token.
  // Hindi ito nagta-throw at hindi ito nakakapigil sa app kung mabigo man
  // — tingnan ang app_check.dart.
  await activateAppCheck();

  FirebaseFirestore.instance.settings = _firestoreSettings();

  // ProviderScope = root ng lahat ng Riverpod providers (auth, session, queue).
  runApp(const ProviderScope(child: ShuttleQueueApp()));
}

/// Ang dalawang font ay nakasilid sa app, kaya ipinapamahagi natin sila sa
/// bawat build. Hinihingi ng SIL Open Font License na kasama ang teksto ng
/// lisensya — dito ito nakakabit, kaya lumalabas ito sa karaniwang
/// "licenses" na pahina ng Flutter nang walang dagdag na screen.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, path) in const [
      ('Inter', 'assets/fonts/OFL-Inter.txt'),
      ('Archivo', 'assets/fonts/OFL-Archivo.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(
        [family],
        await rootBundle.loadString(path),
      );
    }
  });
}

/// Offline-first ang buong app: madalas walang signal ang QM sa court,
/// kaya lahat ng reads/writes ay dapat gumana laban sa local cache.
///
/// Magkaiba ang storage sa dalawang platform:
/// - Android: SQLite sa device. Naka-ON ang persistence by default.
/// - Web: IndexedDB sa browser. Naka-OFF by default, kaya kailangang
///   hingin nang explicit — at kailangan ng tab manager kung hindi natin
///   gustong mag-away ang dalawang tab sa iisang cache.
Settings _firestoreSettings() {
  if (kIsWeb) {
    return Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      // Multiple tabs: kailangan ito kapag nakabukas ang app sa dalawang
      // tab (hal. QM sa isa, Up Next board sa kabila). Kung single-tab
      // lang ang setting, mabibigo ang pangalawang tab na kumuha ng cache.
      webPersistentTabManager: WebPersistentMultipleTabManager(),
    );
  }

  return const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
