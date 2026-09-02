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
