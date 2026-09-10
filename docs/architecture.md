# ShuttleQueue — Architecture

How the app is put together, and *why* — the decisions that would be
expensive to reverse later.

---

## 1. The constraint everything bends around

The Queue Master runs a four-hour session standing courtside, one-handed,
in a gym with weak signal. That single sentence drives every decision below:

- **The app never waits for the network.** Not for a save, not for a screen.
- **Nothing important lives only in widget state** — Android can kill a
  backgrounded app after four hours, and the QM must lose nothing.
- **No confirmation dialogs during a live session.** Undo instead.
- **Big targets, high contrast**, readable at arm's length in a bright hall.

## 2. Layers

```
screens/  ──▶  providers/  ──▶  repositories/  ──▶  Firestore
   │                                  ▲
   └────────▶  services/  ────────────┘  (pure logic — never called by repos)
```

| Layer | Rule |
|---|---|
| `screens/`, `widgets/` | Never import `cloud_firestore`. UI only. |
| `providers/` | Riverpod. Wires repositories to the UI, holds shared listeners. |
| `repositories/` | **The only** code that touches Firestore. Owns all mapping. |
| `services/` | Pure Dart. No Firebase imports at all. |
| `models/` | Plain data classes using `DateTime`, not `Timestamp`. |

**Why models avoid `Timestamp`:** it keeps `MatchmakingService` and
`FeeCalculator` genuinely unit-testable — they run in a plain Dart VM with no
Firebase initialisation. Those two services carry the correctness burden of
the whole product (who plays, who pays), so their testability is worth the
small cost of mapping in the repositories.

**Where the wire format lives:** `repositories/firestore_mappers.dart`, and
nowhere else. Every reader there falls back to a safe default rather than
throwing — a malformed document should cost one wrong skill tier, not a
crash at 10pm.

## 3. Offline-first

Persistence is enabled in `main.dart` with an unlimited cache, per platform:

| | Android | Web |
|---|---|---|
| Store | SQLite | IndexedDB |
| Default | **on** | **off** — must be requested explicitly |
| Multi-tab | n/a | `WebPersistentMultipleTabManager` |

That web default is a genuine trap: adding the web target without setting
`persistenceEnabled: true` would have silently disabled the app's core
guarantee in the browser.

**How the UI shows sync state.** Repositories return `Synced<T>` — the data
plus `hasPendingWrites` — so screens can render the "Saved on this device"
banner without importing Firestore types. It appears on the sessions list,
the roster and the courts screen.

**Writes are optimistic.** `createSession` deliberately does *not* await its
batch commit: offline, that future does not resolve until the network
returns, and awaiting it would freeze the UI at exactly the wrong moment.
The write is already applied to the local cache, so the session appears
instantly. Failures are logged rather than swallowed.

**Auth offline.** Firebase Auth needs the network only for the *first*
sign-in on a device. The persisted session then survives restarts and
airplane mode, which is why the QM is never signed out mid-night.

**Timestamps.** `waitingSince` uses the client clock, deliberately. Server
timestamps are only estimates while offline, and v1 is single-device, so the
client clock is both simpler and more correct here.

## 4. Data model

```
users/{uid}                      displayName, email, role: "qm", createdAt

clubs/{clubId}                   name, ownerUid, createdAt
  members/{memberId}             name, aliases[], skillTier,
                                 balanceCentavos, sessionsAttended,
                                 lastPlayedAt, createdAt

sessions/{sessionId}             ownerUid, clubId, title, venue, sessionDate,
                                 status, courtCount, courtFeeCentavos,
                                 shuttlePriceCentavos, feeMode,
                                 createdAt, updatedAt
  players/{playerId}             name, skillTier, gamesPlayed, waitingSince,
                                 status, shuttlesUsed, hasPaid,
                                 memberId?, createdAt
  courts/{courtId}               label, status, currentMatchId?
  matches/{matchId}              courtId, teamA[2], teamB[2],
                                 scoreA?, scoreB?, startedAt, endedAt?
```

**Money is always integer centavos.** Never a double. Conversion happens once,
at the form boundary (`services/money.dart`).

**The club layer earns its place** by holding what outlives a single night:
remembered skill tiers, nicknames, and carry-over balances. `memberId` on a
session player is nullable — a guest who plays once needs no member record.
Session players keep their own copy of name and tier, so re-tagging someone
tonight never rewrites last month's history.

**Firestore does not cascade deletes.** `deleteSession` walks `players`,
`courts` and `matches` explicitly, in batches of 400 (the hard limit is 500).
Without this, deleted sessions would leave unreachable orphan documents —
and "delete session" has to mean it, under RA 10173.

## 5. The two algorithms

Both are pure, both are the reason the product works.

### MatchmakingService

1. Only `queued` players are eligible.
2. Sort by `gamesPlayed` ascending, then `waitingSince` ascending.
3. Prefer four players within one skill tier of each other.
4. If no clean group exists, fall back to the closest available and **flag
   it** — never block the match.
5. Split strongest + weakest against the middle two.

Plus two safety valves that are not in the original spec but proved
necessary:

- **Long-wait guarantee.** After 25 minutes, a player is force-promoted
  regardless of tier fit. Skill grouping *will* strand the only advanced or
  only beginner player; one person sitting out a whole night is the worst
  outcome this app can produce.
- **No-repeat rotation.** Among players tied on games played, prefer
  combinations that have not played together tonight.

> **The bug worth remembering.** Variety-avoidance was originally allowed to
> reorder the whole queue. A simulation test — 12 players, 12 rotations —
> showed games played drifting to a 2-game spread. Variety is now strictly a
> tie-breaker *within* equal game counts, and long-waiters are selected in
> fairness order rather than by wait alone. The simulation now finishes
> within 1 game across all players, and that test guards the property.

### FeeCalculator

Per-head splits the court fee evenly and charges each player for their own
shuttles; American pools everything and divides equally. Integer division
leaves a remainder, which is handed out one centavo at a time to players
sorted by name — deterministic, so a refresh never changes someone's bill.

The invariant, asserted across 200 fee/headcount combinations: **the parts
sum exactly to the whole.** A centavo lost here is a centavo out of the
Queue Master's own pocket.

*Assumption:* players who left early still pay (spec §5 over §6's wording —
they used the court). One flag flips it.

## 6. Security

Because Flutter talks to Firestore directly, `firestore.rules` **is** the
backend. It enforces two things:

1. **Ownership** — a QM reads and writes only documents whose `ownerUid`
   matches their auth uid. Subcollections check their parent via `get()`.
   `ownerUid` and `createdAt` are immutable after creation.
2. **Shape** — exact field sets (`hasOnly`), types, enum membership, numeric
   ranges, and string length caps on every collection.

Shape validation is not paranoia. Without it any signed-in client can write
`gamesPlayed: -999` and quietly destroy the fairness ordering, or store a
900 KB string as a player name. The `gamesPlayed >= 0` rule also acts as a
backstop for a buggy undo.

**Tested, not assumed.** `test_rules/` runs 34 checks against the local
Firestore emulator: every real write path succeeds, anonymous access fails,
a second QM is denied on every collection, immutable fields reject changes,
and each malformed-data case is refused.

```bash
cd test_rules && npm install && npm test
```

## 7. Cost control

Firestore's free tier allows 50k reads/day. A naive live-queue screen — one
listener per row, re-reading the roster on every change — can approach that
in a single evening. Every collection therefore has **one shared listener at
the provider level**, and screens read from that. Client-side sorting is
preferred over extra composite indexes where the collection is small.

## 8. What v2 hooks into

- **Up Next board** — a read-only second screen showing courts and queue.
  The multi-tab cache manager is already configured for it.
- **Night recap cards** — every number needed already exists in `matches`.
- **Private skill rating** — `matches` stores teams and outcomes; a rating
  would be a pure service alongside `MatchmakingService`.
- **Cloud Functions** — deliberately absent in v1 (they require the paid
  Blaze plan). `FeeCalculator` is a pure function behind a clean boundary,
  so moving it server-side later is a lift-and-shift.
- **Co-QM handoff** — blocked on conflict resolution. Two devices editing
  offline resolve last-write-wins today. The honest fix is an append-only
  event log where live state is derived, which merges correctly by
  construction. v1 is single-device by declaration.

---

## 9. Field notes: the bugs that cost real data

Every entry here was found in the deployed app, not in review. They are
recorded because each one has a general lesson, and because the symptom in
each case looked nothing like the cause.

### Firestore rules evaluate against *pre-batch* state

**Symptom.** Creating a session appeared to work, then the session vanished a
second later.

**Cause.** The rules proved a child document's ownership by calling `get()` on
its parent session. Inside a `WriteBatch`, rules see the state *before* the
batch, so the parent did not exist yet. The read returned null, the rule threw,
the whole batch was rejected — and Firestore rolled back the optimistic local
write. The disappearing card was the rollback.

**Fix.** `ownerUid` is denormalised onto every child document, and the rules
contain zero `get()` calls. It also removes one document read per operation.

**Lesson.** A rule that reads another document cannot be trusted inside a
batch. Denormalise the field you need to check.

### Rules are not filters

**Symptom.** Taps did nothing. Roster, courts, matches, money and regulars all
spun forever.

**Cause.** Removing those `get()` calls left rules resting on
`resource.data.ownerUid`. Firestore cannot prove that predicate for an
unconstrained collection query, so it rejects the query outright rather than
returning the subset that matches.

**Fix.** Every collection query repeats the rule's condition —
`where('ownerUid', isEqualTo: uid)` — via `ownedQuery` in
`repositories/deferred_write.dart`.

**Lesson.** A query must restate what its rule requires. And the test gap that
hid this for weeks: every rules test used `getDoc`, never `getDocs`. There are
now eleven list-query checks asserting that the unfiltered query is denied
*and* the filtered one is allowed.

### Reading a missing field in rules is an error, not null

**Symptom.** Club creation silently denied, which later broke saving the GCash
number.

**Cause.** `validClub` read `data.gcashNumber` directly. A brand-new club has
no such field, and in the rules language that read is an error rather than
null.

**Fix.** `data.get('gcashNumber', null)` for every optional field.

**Lesson.** The blind spot was the fixture: club tests all seeded a club with
rules disabled, so `create` was never exercised. Test the path that runs on a
user's very first day.

### Firestore write futures never resolve while offline

**Symptom.** None yet — found by audit before it reached the gym.

**Cause.** Twenty-two mid-session writes did a bare `await` on the Firestore
future. Offline, that future does not complete until the write reaches the
server, so end-match, undo, add-player and the rest would have hung forever at
a gym with no signal. The one write that was correct was `createSession`,
because it had been written first and copied wrong afterwards.

**Fix.** `fireAndForget(write, onError)` everywhere, plus a `syncErrorProvider`
snackbar so a rejected deferred write is never silent again. That invisibility
was the real defect.

**Lesson.** In an offline-first app, `await` on a write is a bug. The local
cache is the source of truth; the network is an eventual detail.

### The duplicate club: cache-only lookups of server state

**Symptom.** The GCash number disappeared from the Money tab.

**Cause.** `ensureDefaultClub` looked for the existing club **cache-only**.
Cache-first is right when the cache is the truth — but this was a lookup of
*server state we might never have seen*. On a fresh browser the cache is empty,
so the app concluded "new Queue Master" and created a second club, abandoning
the regulars book, the carry-over balances and the GCash number. A REST query
found three clubs on one account, with eight regulars on one and the phone
number on another: the history was genuinely **split**.

**Fix, in two halves.** *Prevention* — every launch reconciles cache against
the server on a bounded timeout, falling back to cache so the QM is never
blocked. *Repair* — `pickPrimaryClub` chooses most-members, then oldest, then
id, and adopts an orphaned GCash number from a duplicate. If duplicates
disagree on the number it stays empty; that field is where players send money,
so a wrong number is worse than none.

**Lesson.** "Cache is the truth" is a claim about *ownership of the data*, not
a blanket policy. And `limit(1)` without an `orderBy` is not deterministic —
two devices can disagree about which document they found.

### A lazy field initialised inside dispose()

**Symptom.** Caught by a widget test the same day the code was written.

**Cause.** The pulsing LIVE dot held its controller in
`late final _controller = AnimationController(...)`. With reduce-motion
enabled, `build` returned early and never touched it — so `dispose()` became
the first access, constructing a ticker on an already-deactivated element.

**Fix.** Build it in `initState`, start and stop it in
`didChangeDependencies`.

**Lesson.** `late final` with an initialiser is lazy. If the only access is
conditional, the first access can be teardown. Also: an infinite `repeat()`
makes `pumpAndSettle` hang forever, so widget tests wrap the tree in
`MediaQuery(disableAnimations: true)`.

### Flutter web does not content-hash main.dart.js

**Symptom.** Fixes were deployed and verified, and the user still saw the old
app.

**Cause.** Hosting served `main.dart.js` as `immutable, max-age=31536000`, but
Flutter does not fingerprint that filename. Browsers will not even revalidate
an immutable resource.

**Fix.** `Cache-Control: no-cache` for everything; ETags still make repeat
loads cheap.

**Lesson.** Immutable caching requires content-addressed filenames. If a user
ever reports that a fix did not appear, the first question is what the browser
was allowed to cache.

---

## 10. What the tests are actually for

220 Dart tests and 56 rules checks, and the split is deliberate.

The **pure services** carry the correctness burden and are tested hardest,
because they decide who plays and who pays: matchmaking, fee calculation,
roster parsing, name matching, night recap, session grouping, account
security. No Firestore import appears in any of them.

The **widget tests** exist because of one repeated lesson: a tested service
behind a broken screen still shows the user nothing. The recap tab, the bill
lock, the dashboard and the sign-in form are all pumped for real. The bill-lock
test is the one worth keeping honest — with the bill locked and a fifth player
arriving, the four who already paid must still read the same amount.

The **rules tests** run against the emulator and assert denial as carefully as
success, including the batch-create shape that caused the vanishing sessions
and the list queries that caused the dead taps.

What is *not* covered, and should be said plainly: `fake_cloud_firestore`
ignores `GetOptions`, so the cache-versus-server behaviour of the club lookup
is reasoned about and observed in production, but not unit-tested.
