# ShuttleQueue

Queue-Master-first badminton queueing & session management. One coach (the
Queue Master) runs an entire social badminton night — attendance, fair match
rotation, and end-of-night cost splitting — from her phone, **fully offline**,
syncing to the cloud when signal returns.

Built with Flutter (Android-first) + Firebase (Firestore, Auth) on the free
Spark tier. State management: Riverpod.

## Status

| Milestone | Scope | Status |
|---|---|---|
| M0 | Scaffold, toolchain, Firebase wiring, offline persistence | ✅ |
| M1 | Queue Master auth (email/password) | — |
| M2 | Sessions + Messenger roster import + live roster editing | — |
| M3 | Courts + fair rotation (MatchmakingService) | — |
| M4 | Cost split (FeeCalculator, per-head / american) | — |
| M5 | Firestore security rules + offline polish + docs | — |

## Setup

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
   (this project uses 3.44.x stable) and run `flutter doctor` until clean.
2. `flutter pub get`
3. Firebase (one-time, per machine):
   ```
   npm i -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --project=badminton-ph --platforms=android
   ```
   This generates `lib/firebase_options.dart` (gitignored — regenerate, don't
   copy from someone else).
4. Run: `flutter run` &nbsp;·&nbsp; Test: `flutter test` &nbsp;·&nbsp; Lint: `flutter analyze`

## Folder structure

```
lib/
  main.dart          # bootstrap: Firebase init, offline persistence, ProviderScope
  app.dart           # MaterialApp, theme (large targets, high contrast), routes
  l10n/              # ALL user-facing strings (app_en.arb); Taglish locale later
  models/            # plain Dart data classes mirroring the Firestore contract
  services/          # PURE logic — matchmaking, fee calc, roster parsing. No Firestore.
  repositories/      # the ONLY layer that talks to Firestore
  providers/         # Riverpod providers wiring repositories to the UI
  screens/           # one file per screen
  widgets/           # shared, reusable widgets
test/                # unit tests for services + widget smoke tests
docs/architecture.md # offline-first design & data model notes
firestore.rules      # security rules (deployed at M5)
```

**Architecture rule of thumb:** UI → providers → repositories → Firestore.
Algorithms (`services/`) are pure Dart with zero Firebase imports so they are
unit-testable in isolation.

## Offline-first

Firestore persistence is enabled with an **unlimited local cache**
([main.dart](lib/main.dart)). The QM can run an entire session with zero
connectivity; writes queue locally and sync when the network returns. The UI
must always render from the cache and never block on the network.
