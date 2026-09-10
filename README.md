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
| M6 | Up Next board — read-only second screen for the hall | ✅ |
| M7 | Night recap — per-player summary, shareable | ✅ |
| — | Regulars book, carry-over balances, bill locking, snapshot export | ✅ |
| — | On-court substitution, session templates, GCash number | ✅ |
| — | Own brand mark, hardened sign-in, Queue Master dashboard | ✅ |

Deliberately **not** built: winner-stays / king-of-court rotation, and a GCash
QR on the bill. Both need the coach's answer first — which format her club
actually plays, and whether she wants her QR shown. Guessing would be worse
than waiting.

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
flutter test                          # 220 unit + widget tests
cd test_rules && npm install && npm test   # 56 security-rules checks
```

The rules tests run against the local Firestore emulator (needs Java — the
JDK bundled with Android Studio works: set `JAVA_HOME` to
`C:\Program Files\Android\Android Studio\jbr`). They never touch the real
project.

Before a real night, drive [docs/trial-night.md](docs/trial-night.md) end to
end — a 20-minute scripted dry run through one imaginary session, including a
deliberately awful roster paste.

CI runs `flutter analyze`, the Dart tests and the rules tests on every push —
see [.github/workflows/ci.yml](.github/workflows/ci.yml). For which
production concerns apply to a client-only Firebase app and which genuinely
don't, see
[docs/production-readiness.md](docs/production-readiness.md).

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
| Recap | Per-player night summary — games, partners, longest wait — shareable to the group chat |
| Regulars | Remembered skill tiers, nicknames and carry-over balances |

Pure, tested services carry the correctness burden: `MatchmakingService`
(who plays next), `FeeCalculator` (who owes what), `RosterParser` (the
Messenger paste), `NameMatcher` (recognising regulars) and
`SessionSnapshot` (the offline backup). See
[docs/architecture.md](docs/architecture.md).

**Export all my data** (dashboard overflow menu) writes the club, the regulars
book with its balances, and every session with its players, matches and bill to
a single JSON file. Firestore's scheduled backups are a paid-tier feature, so on
the free tier this is the only copy of that data outside Firebase — and it
doubles as RA 10173 data portability.

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

### Building the Android app

```bash
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk` (~55 MB).
Copy it to the phone and open it; Android will ask permission to install from
an unknown source, because **this build is signed with the debug key** — see
the TODO in `android/app/build.gradle.kts`. That is fine for sideloading onto
the Queue Master's own phone and *not* fine for the Play Store, which needs a
real upload keystore.

## App Check

Security rules stop another signed-in user reading your data. They do **not**
stop someone taking the public API key and burning through the free daily
quota — and when that quota is gone, the app stops for everyone, including the
Queue Master mid-session. App Check closes that hole.

It is wired in [lib/app_check.dart](lib/app_check.dart) and **deployed**, using
**reCAPTCHA Enterprise** — Firebase has deprecated the plain reCAPTCHA v3
provider for App Check. Until the console side is complete, and until you
choose to enforce, nothing is blocked: attestation failures are swallowed.

### Turning it on

1. Get a **reCAPTCHA Enterprise** site key with domains `badminton-ph.web.app`
   **and** `badminton-ph.firebaseapp.com`. A key made at
   [google.com/recaptcha/admin](https://www.google.com/recaptcha/admin) works —
   Google now backs those with Enterprise — **but it should belong to the
   `badminton-ph` Google Cloud project**. A key living in another project is a
   common cause of `403 App attestation failed`.
2. Firebase Console → **Build → App Check → Apps** → register the web app with
   **reCAPTCHA Enterprise**, pasting that site key. Enterprise needs no secret;
   it authenticates through the Cloud project. Ignore the plain "reCAPTCHA"
   option — that is the deprecated one.
3. Redeploy. The site key has a default baked into `lib/app_check.dart` (it is
   public — it ships inside every page), so a plain build keeps App Check on;
   a forgotten flag can no longer switch it off silently:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```
   Pointing at a different project? Override it, and **run `flutter clean`
   first** — changing or removing a `--dart-define` does not invalidate
   Flutter's incremental build, so the old value survives and App Check goes
   quietly dead. Verify with `grep -c recaptcha build/web/main.dart.js`.
4. **Leave every API unenforced.** Watch App Check → APIs for a few days until
   your own traffic shows as verified.
5. Only then enforce.

### The trap

Enforcing early blocks **your own app**, including the coach's phone, with
twelve people waiting on court. Two specific things to check before enforcing:

- **Android cannot use Play Integrity here.** It requires distribution through
  Google Play, and our APK is sideloaded and debug-signed — so the debug
  provider is used. Before enforcing Firestore, register that phone's debug
  token under App Check → Apps → Android → Manage debug tokens, or the coach is
  locked out.
- Attestation failures are swallowed by design. The app keeps working; App
  Check is a shield against abuse, not a new way to lose the night.
- **`403 App attestation failed`** means the app is registered but Firebase
  rejected the token. Check, in order: the key registered in App Check is the
  same one in `lib/app_check.dart`; that key belongs to the `badminton-ph` Cloud
  project; and the minimum score under Advanced settings (default 0.5) is not
  turning away real visitors.

## Brand

The shuttlecock mark is drawn once, in two places that must agree:

- `tool/generate_icons.py` — run `python tool/generate_icons.py` to regenerate
  the favicon, the PWA icons (including maskable), and every Android launcher
  density from a single definition.
- `lib/widgets/shuttle_mark.dart` — the same geometry as a `CustomPainter`, so
  the in-app logo and the installed icon cannot drift apart.

## Sign-in

Built against [web.dev's sign-in form best practices](https://web.dev/articles/sign-in-form-best-practices),
adapted to Flutter — which renders to canvas, so there is no real `<label for>`
to hand a browser. The part that does carry over is the important one:
`AutofillGroup` plus `autofillHints` makes Flutter emit genuine DOM inputs with
`autocomplete="username"` / `current-password` (`new-password` when
registering), stable `name`/`id`, and a submit control. That is exactly what
browser password managers look for, and it is why a Queue Master ends up with a
long unique password instead of a reused one.

On top of the article: one password field ever, paste never blocked, a visible
password reset, errors announced through `Semantics(liveRegion: true)`, and the
show-password control carrying its on-screen warning in the semantic label.

Two rules live in `lib/services/account_security.dart` and are unit-tested:

- **Eight characters minimum — for new accounts only.** Firebase's floor is
  six; accounts created under it must still be able to sign in. Locking someone
  out of tonight to enforce a policy is the wrong trade.
- **Failed-attempt backoff** grows 15s → 300s, and counts *wrong passwords
  only*. A network failure never counts, because a Queue Master at the gym with
  no signal must never be locked out of her own session.

The password reset replies with the same message whether or not the account
exists. Otherwise the sign-in page becomes a tool for checking who has an
account.

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
