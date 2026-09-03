# ShuttleQueue

Queue-Master-first badminton queueing & session management. One coach (the
Queue Master) runs an entire social badminton night — attendance, fair match
rotation, and end-of-night cost splitting — from her phone, **fully offline**,
syncing to the cloud when signal returns.

**Live:** https://badminton-ph.web.app

Built with Flutter + Firebase (Firestore, Auth) on the free Spark tier.
State management: Riverpod. **One codebase, two targets: Android and web.**

## Status

| Milestone | Scope | Status |
|---|---|---|
| M0 | Scaffold, toolchain, Firebase wiring, offline persistence | ✅ |
| M1 | Queue Master auth (email/password) | ✅ |
| M2 | Sessions + Messenger roster import + live roster editing | ✅ |
| M3 | Courts + fair rotation (MatchmakingService) | ✅ |
| M4 | Cost split (FeeCalculator, per-head / american) | ✅ |
| M5 | Rules hardening (field validation) + polish + docs | ✅ |

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
4. Run on Android: `flutter run -d emulator-5554`
5. Run in a browser: `flutter run -d chrome`
6. Test: `flutter test` &nbsp;·&nbsp; Lint: `flutter analyze`
7. Ship the web build: `flutter build web --release` then `firebase deploy --only hosting`

## Testing

```bash
flutter analyze                       # static analysis, must be clean
flutter test                          # 55 unit + widget tests
cd test_rules && npm install && npm test   # 34 security-rules checks
```

The rules tests run against the local Firestore emulator (needs Java — the
JDK bundled with Android Studio works: set `JAVA_HOME` to
`C:\Program Files\Android\Android Studio\jbr`). They never touch the real
project.

**The acceptance test that actually matters** is the offline drill:
airplane mode on → create a session → paste a roster → run three rotations
on two courts → compute fees → airplane mode off → confirm everything
appears in the Firestore console and the pending-sync banner clears.

## What runs the night

| Screen | Job |
|---|---|
| Sessions | Every night this Queue Master has run |
| Roster | Paste-import from Messenger, skill tiers, late arrivals, leavers |
| Courts | The court grid, the queue, and one big **Next match** button |
| Money | Per-player breakdown, lockable amounts, paid toggles, share to the group chat |
| Board | A read-only second screen: courts and the queue, visible across the hall |
| Regulars | Remembered skill tiers, nicknames and carry-over balances |

Pure, tested services carry the correctness burden: `MatchmakingService`
(who plays next), `FeeCalculator` (who owes what), `RosterParser` (the
Messenger paste), `NameMatcher` (recognising regulars) and
`SessionSnapshot` (the offline backup). See
[docs/architecture.md](docs/architecture.md).

**Two safety nets worth knowing about.** *Save a copy of tonight* (the save
icon) exports the whole session as plain text — it works with no signal and
survives a dead battery, which is the single worst way this app could fail
its user. And *Lock the amounts* on the Money tab freezes everyone's share
before collection starts, so a late arrival can never silently change what
someone already paid.

## Privacy (RA 10173)

Player names and skill tiers only — no phone numbers, no emails, no
addresses. The import screen says so in plain language. Deleting a session
really deletes its players, matches and fees; Firestore does not cascade, so
the app removes each document explicitly.

## Platforms

| | Android | Web |
|---|---|---|
| Install | APK sideload | just a link; installable to the home screen |
| Offline store | SQLite, on by default | IndexedDB, enabled explicitly in `main.dart` |
| Multi-tab | n/a | `WebPersistentMultipleTabManager` so two tabs share one cache |
| Best for | the QM's own phone on trial night | demos, laptops, and the future Up Next board |

**Known web limits.** Private/incognito windows disable IndexedDB, so offline
mode will not persist there. Browsers may evict site storage under heavy disk
pressure. Both are why the Android build stays the recommendation for the
Queue Master's live session.

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
