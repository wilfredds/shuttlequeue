# ShuttleQueue — Architecture Notes

> Stub — filled out progressively per milestone; completed at M5.

## Offline-first design (M0)

- Firestore offline persistence is enabled in `lib/main.dart` with
  `CACHE_SIZE_UNLIMITED` so nothing is evicted during a 4-hour offline session.
- Every screen renders from the local cache; pending writes are surfaced via
  `snapshot.metadata.hasPendingWrites` (sync indicator lands in M5).
- Firebase Auth requires network only for the *first* sign-in on a device;
  the persisted session keeps the QM logged in offline afterward.
- Ordering fields (`waitingSince`) use client-side `Timestamp.now()` —
  deterministic offline, and single-device by design in v1.

## Data model

Firestore, per the v1 contract (see the master spec §4):

```
users/{uid}
sessions/{sessionId}
  players/{playerId}
  courts/{courtId}
  matches/{matchId}
```

Money is stored as **integer centavos** — never floats.

## v2 hook points

- Trusted computation (fee finalization, skill ratings) moves to Cloud
  Functions — requires the Blaze plan, which is why v1 keeps `FeeCalculator`
  client-side behind a pure service boundary.
- Player-side app / self-join codes, push notifications, ELO/TrueSkill,
  GCash/Maya rails: all hang off the same session document tree.
