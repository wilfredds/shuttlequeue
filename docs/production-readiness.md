# Production readiness — the checklist, honestly applied

There is a well-travelled list of things "vibe coders" supposedly don't know
about: rate limiting, Kubernetes, circuit breakers, sharding, SLOs, and about a
hundred more. It is a good list. It is also a list of concerns for **systems
with servers you operate**.

ShuttleQueue has no servers. It is a Flutter client talking directly to
Firestore, with security rules as the trust boundary. So the useful exercise is
not to implement all of it — that would be cargo cult, and several items would
actively make this app worse. The useful exercise is to go item by item and say
which bucket it falls in, and why.

Four buckets: **Google's problem**, **already built**, **not applicable**, and
**a real gap** — with the last one being the only part that should cost anyone
sleep.

---

## 1. Google's problem, not ours

These come with Firestore, Firebase Auth and Firebase Hosting. Re-implementing
any of them would mean writing something worse than what already runs.

| Concern | Who handles it |
|---|---|
| Load balancing, reverse proxies, API gateways | Google's edge, in front of every Firestore and Hosting request |
| Autoscaling, horizontal & vertical scaling | Firestore scales without a knob to turn |
| CDN, edge caching | Firebase Hosting is a CDN |
| Replication, read replicas, failover, leader election | Firestore internals |
| Sharding, partitioning, connection pooling | Firestore internals |
| TLS, encryption in transit, encryption at rest | On by default; not optional, not configurable |
| DDoS protection, WAF | Google's edge infrastructure |
| DNS, TCP vs UDP, HTTP/2 & HTTP/3, gRPC | Hosting serves HTTP/2; the SDK uses gRPC on Android and WebChannel on web |
| JWT rotation | Firebase ID tokens expire hourly and the SDK refreshes them silently |
| Rate limiting (auth) | Firebase Auth throttles repeated failures server-side |

**One nuance worth knowing.** Firestore has no *per-user* request limit. The
protection against someone hammering the database with a copied API key is
security rules plus Firebase App Check — see the gaps section.

**And a common misunderstanding:** the Firebase API key in
`lib/firebase_options.dart` is **not a secret**. It identifies the project; it
does not authorise anything. The rules are the security boundary. This is why
"secrets management" has no work item here — the app holds no secrets. The file
is gitignored to keep the repo unattached to one project, not to hide a key.

## 2. Already built into this app

| Concern | Where |
|---|---|
| Caching | Firestore offline persistence, unlimited local cache (`main.dart`) |
| Cache invalidation | The `main.dart.js` incident — see architecture §9 |
| Retries, exponential backoff | Firestore SDK retries; sign-in has its own backoff (`account_security.dart`) |
| Rate limiting (client) | `signInLockout` — 15s → 300s, wrong passwords only |
| Idempotency | `FieldValue.increment` for attendance and balances, so replayed offline writes stay correct |
| Optimistic locking | Every write is local-first and optimistic; the server is the eventual arbiter |
| Race conditions | Found and fixed one for real — the duplicate club (architecture §9) |
| CAP theorem | Chosen deliberately: **AP**. The app stays available under partition and converges later |
| Eventual consistency | The entire offline-first design |
| Network partitions | Airplane mode is the acceptance test (`docs/trial-night.md`) |
| Chaos engineering | Same drill — kill the network mid-session and keep running |
| Distributed transactions | `WriteBatch` for anything that must be all-or-nothing (starting a match writes court, match and session status atomically) |
| WebSockets / long polling / SSE | Firestore listeners give realtime without any of it |
| Event-driven architecture, pub/sub | Snapshot listeners *are* the event stream |
| Database indexing, query optimization | `firestore.indexes.json`; `watchMembers` deliberately sorts client-side to avoid needing a composite index |
| N+1 queries | One shared listener per session, not one per widget (R-12) |
| Thread safety, deadlocks | Dart is single-threaded with an event loop; there are no locks to deadlock |
| Memory leaks, garbage collection | Riverpod disposes providers; controllers are disposed explicitly — and one leak-shaped bug was caught by a test (architecture §9) |
| Infrastructure as code | `firestore.rules`, `firestore.indexes.json`, `firebase.json` are versioned in git and deployed from the CLI. That *is* IaC; it just isn't Terraform |
| Postmortems | `docs/architecture.md` §9 — seven incidents, cause and lesson each |
| Cost optimization | Free tier by design: shared listeners, no Cloud Functions, no paid services |
| Dependency hell | `pubspec.lock` is committed; CI installs from it |
| Latency, throughput, P99 | Reads come from local disk, so perceived latency is storage speed, not network. This is the whole point of the architecture |
| Semantic versioning | `lib/app_version.dart`, shown on the sign-in screen, with a test that fails if it drifts from `pubspec.yaml` |
| CI/CD | `.github/workflows/ci.yml` — analyze, 205 tests, and 56 rules checks on every push |
| Blue-green / canary / rollback | `firebase hosting:channel:deploy` gives a preview URL to test before promoting; Hosting keeps release history and can roll back from the console |

## 3. Not applicable — and why

Saying "not applicable" is only honest if you can say why.

- **Docker, Kubernetes, Helm, Terraform, service discovery, health checks,
  liveness & readiness probes** — these orchestrate servers. There are none.
- **SQL injection** — there is no SQL. Firestore takes structured queries, not
  strings.
- **XSS** — Flutter renders to a canvas. There is no `innerHTML` to inject
  into, and no user-supplied HTML anywhere.
- **CSRF** — no cookie-based sessions. Auth is a bearer token in a header,
  which is not sent automatically by a browser on a cross-site request.
- **CORS** — Firestore and Hosting set their own headers correctly.
- **SSRF** — nothing server-side makes outbound requests on a user's behalf.
- **Message queues, dead letter queues, saga pattern, backpressure** — one
  Queue Master writes to their own data. There is no fan-out, no throughput
  problem, and nothing to queue.
- **Circuit breakers** — there is exactly one downstream (Firestore) and the
  correct behaviour when it is unreachable is to keep working from cache, which
  the SDK already does.
- **Distributed locks, pessimistic locking** — single writer per session.
- **Cold starts, serverless limits** — no Cloud Functions in v1.
- **Cron jobs** — nothing runs on a schedule. Session templates cover the
  weekly repeat without a scheduler.
- **API versioning, webhooks, gRPC design** — the app publishes no API.
- **On-call, error budgets, SLOs, SLIs** — meaningful for a team with a pager
  and a customer contract. This is one coach on a Thursday night; the SLO is
  "the night finished".

**Clock skew** deserves a longer answer than "N/A". Queue order depends on
`waitingSince`, which is written from the device clock. If that clock is wrong,
*every* timestamp is wrong by the same amount, so the relative ordering — which
is all fairness depends on — is unaffected. It would only matter across two
devices, which v1 does not do. The one place a wrong clock does bite is
`nextOccurrence` when scheduling the following week.

## 4. Real gaps

These are genuine, and listed worst-first. None of them should be done in the
week before a client demo; changing infrastructure right before a demo is how
working software stops working.

### ~~Backups~~ — closed

Firestore's scheduled backups and point-in-time recovery are **Blaze-tier
features**. On Spark there is no automated backup, so if data were deleted — by
a bug, or by the Queue Master tapping delete — it was gone.

**Now:** *Export all my data*, in the dashboard overflow menu. It gathers the
club, the whole regulars book with its carry-over balances, and every session
with its players, courts, matches and bill, then hands over a single
`shuttlequeue-YYYY-MM-DD.json` file. Document IDs are preserved, so the
relationships between a match, its players and their regulars-book entries
survive the round trip — a backup you cannot restore from is not a backup.

It also answers RA 10173 data portability: the Queue Master's data, in a format
any other program can open.

Two things worth knowing:

- It reads from the **server** rather than the cache. Every other read in this
  app is cache-first for speed; a backup wants the freshest and most complete
  data instead. Offline, the SDK falls back to cache, so a partial backup still
  beats none.
- Cost is roughly `sessions x 4 + 2` reads. A full thirty-night season is about
  2,500 reads against a free daily allowance of 50,000 (R-12). Fine as an
  occasional action; not something to put on a timer.

**Still open:** nothing restores *from* the file yet. Rebuilding would be a
manual import, which is the honest state of a v1 backup — the data is safe
outside Firestore, which is the part that could not be recovered any other way.

### No crash reporting

If the app throws on the coach's phone during a real night, nobody finds out.
Rejected writes surface as a snackbar via `syncErrorProvider`, but an actual
crash is silent.

**Recommended:** Firebase Crashlytics, which is free. Note the limitation
honestly — Crashlytics does not support Flutter web, so this would cover the
Android build only.

### ~~No abuse protection on Firestore~~ — wired, awaiting configuration

Rules stop a signed-in user from touching another Queue Master's data. They do
not stop someone from taking the public API key and hammering the project to
burn through the free quota.

**Now:** App Check is wired in `lib/app_check.dart`, and deliberately stays
inert until a reCAPTCHA v3 site key is supplied at build time — so nothing
changes until it is configured. The README has the console steps.

**Still to do, and the order matters:** register the web app, redeploy with the
site key, then leave every API **unenforced** while the metrics settle.
Enforcing early blocks your own app. Android is the sharp edge: Play Integrity
needs Google Play distribution and our APK is sideloaded, so it uses the debug
provider and that phone's token must be registered before Firestore is
enforced.

### Schema versioning and migrations

The rules validate fields strictly and reject unknown ones. That is good
security and it has a sharp operational edge:

> **Any new field requires deploying `firestore.rules` *before* the app code
> that writes it.** Deploy in the other order and every write is rejected.

There is also no `schemaVersion` on documents, so a future breaking change has
no way to tell old data from new.

**Recommended:** add `schemaVersion: 1` to session documents now, while there
is little data, so that a v2 migration has something to branch on.

### Observability beyond crashes

No metrics, no logs, no traces. For one Queue Master this is mostly fine — the
feedback loop is a phone call. But there is no way to answer "how long did that
import take on her phone".

**Recommended, low priority:** Firebase Performance Monitoring (free) if that
question ever becomes worth answering.

### Feature flags

Shipping a change to the coach mid-season means a redeploy with no way back
except another redeploy. Firebase Remote Config is free and would allow, for
example, turning on a new rotation format for her club alone.

**Recommended:** only once there is a second format to flag. Until then it is
infrastructure with nothing to configure.

### Sign-in without a password

Google Sign-In would remove the password problem for a coach entirely — no
reset flow, no lockout, no forgotten password mid-night.

**Recommended:** worth doing, worth doing *after* the trial.

---

## The short version

Of roughly 110 items on that list: about 45 are Google's problem, about 40 do
not apply to a client-only app, roughly 25 were already handled here, and six
were real gaps. **Backups — the only one that could lose data permanently — is
now closed.** Four remain, led by crash reporting; App Check is wired and awaiting its key.

The skill the list is really testing is not knowing all the words. It is being
able to say, for each one, which of those four buckets it lands in for the
system actually in front of you — and being willing to say "not applicable"
out loud, with a reason, instead of adding a message queue to a badminton app.
