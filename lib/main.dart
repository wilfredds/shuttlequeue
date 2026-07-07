import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Offline-first ang buong app: ang QM ay madalas walang signal sa court,
  // kaya lahat ng reads/writes ay dapat gumana laban sa local cache.
  // Unlimited cache para hindi ma-evict ang data sa gitna ng 4-hour session.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ProviderScope = root ng lahat ng Riverpod providers (auth, session, queue).
  runApp(const ProviderScope(child: ShuttleQueueApp()));
}
