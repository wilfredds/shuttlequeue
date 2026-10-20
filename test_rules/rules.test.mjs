/**
 * Firestore security rules tests.
 *
 * Tumatakbo laban sa lokal na emulator — walang nagagalaw sa totoong
 * shuttlequeue-ph project. Tatlong tanong ang sinasagot nito:
 *
 *   1. Gumagana pa ba ang app? (dapat pumasa ang totoong writes)
 *   2. Naka-lock ba ang datos ng ibang QM?
 *   3. Napipigilan ba ang pangit na datos? (R-11)
 *
 * Patakbuhin: cd test_rules && npm test
 */
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection, addDoc, writeBatch, query, where } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const OWNER = 'qm-alice';
const INTRUDER = 'qm-bob';
const SESSION = 'session-1';
const CLUB = 'club-1';

let env;
let ownerDb;
let intruderDb;

const results = [];

async function check(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
    console.log(`  PASS  ${name}`);
  } catch (error) {
    results.push({ name, ok: false, error: error.message });
    console.log(`  FAIL  ${name}\n        ${error.message}`);
  }
}

function ts(date = new Date()) {
  return date;
}

const validSession = (ownerUid = OWNER) => ({
  ownerUid,
  clubId: CLUB,
  title: 'Monday Night Palo',
  venue: 'Yspacio, Alapan, Imus',
  sessionDate: ts(),
  status: 'setup',
  courtCount: 2,
  courtFeeCentavos: 120000,
  shuttlePriceCentavos: 10000,
  feeMode: 'per_head',
  billFinalizedAt: null,
  createdAt: ts(),
  updatedAt: ts(),
});

const validPlayer = (overrides = {}) => ({
  ownerUid: OWNER,
  name: 'Jun',
  skillTier: 'intermediate',
  gamesPlayed: 0,
  waitingSince: ts(),
  status: 'queued',
  shuttlesUsed: 0,
  hasPaid: false,
  memberId: null,
  createdAt: ts(),
  ...overrides,
});

async function main() {
  env = await initializeTestEnvironment({
    projectId: 'shuttlequeue-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  await env.clearFirestore();

  ownerDb = env.authenticatedContext(OWNER).firestore();
  intruderDb = env.authenticatedContext(INTRUDER).firestore();
  const anonDb = env.unauthenticatedContext().firestore();

  // Seed: ang session at club ni Alice, isinulat nang walang rules.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'sessions', SESSION), validSession());
    await setDoc(doc(db, 'clubs', CLUB), {
      name: "Alice's club",
      ownerUid: OWNER,
      createdAt: ts(),
    });
  });

  console.log('\n1. Anonymous access is blocked everywhere');
  await check('anonymous cannot read a session', () =>
    assertFails(getDoc(doc(anonDb, 'sessions', SESSION))));
  await check('anonymous cannot create a session', () =>
    assertFails(addDoc(collection(anonDb, 'sessions'), validSession())));
  await check('anonymous cannot read a club', () =>
    assertFails(getDoc(doc(anonDb, 'clubs', CLUB))));

  console.log('\n2. The real app still works');
  await check('owner reads their own session', () =>
    assertSucceeds(getDoc(doc(ownerDb, 'sessions', SESSION))));
  await check('owner creates a session', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'sessions'), validSession())));
  await check('owner updates the session title', () =>
    assertSucceeds(updateDoc(doc(ownerDb, 'sessions', SESSION), {
      title: 'Friday Night Smash',
      updatedAt: ts(),
    })));
  await check('owner adds a player', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'), validPlayer())));
  await check('owner adds a court', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'sessions', SESSION, 'courts'), {
      ownerUid: OWNER,
      label: 'Court 1',
      status: 'free',
      currentMatchId: null,
    })));
  await check('owner starts a match', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'sessions', SESSION, 'matches'), {
      ownerUid: OWNER,
      courtId: 'court-1',
      teamA: ['p1', 'p2'],
      teamB: ['p3', 'p4'],
      scoreA: null,
      scoreB: null,
      startedAt: ts(),
      endedAt: null,
    })));
  await check('owner adds a club member', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'clubs', CLUB, 'members'), {
      ownerUid: OWNER,
      name: 'Jun',
      skillTier: 'advanced',
      aliases: ['Kuya Jun'],
      balanceCentavos: 0,
      sessionsAttended: 0,
      lastPlayedAt: null,
      createdAt: ts(),
    })));
  await check('a guest player with a null memberId is allowed', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ name: 'Rica +1', memberId: null }))));

  // THE REGRESSION TEST. The app creates a session and its courts in ONE
  // batch, so the court rule's get() on the parent session runs against
  // state where that parent does not exist yet. This is exactly what made
  // a brand new session vanish a second after the QM tapped Create.
  await check('owner creates a session AND its courts in one batch', () => {
    const batch = writeBatch(ownerDb);
    const newSession = doc(collection(ownerDb, 'sessions'));
    batch.set(newSession, validSession());
    batch.set(doc(collection(newSession, 'courts')), {
      ownerUid: OWNER, label: 'Court 1', status: 'free', currentMatchId: null,
    });
    batch.set(doc(collection(newSession, 'courts')), {
      ownerUid: OWNER, label: 'Court 2', status: 'free', currentMatchId: null,
    });
    return assertSucceeds(batch.commit());
  });

  // startMatch writes the match, the court, the players AND flips the
  // session to live — all in one batch. The session doc already exists
  // here so this is safe, but it is a new combination, and the last batch
  // regression cost real debugging time, so it gets a test.
  await check('owner starts a match and flips the session live in one batch',
    () => {
      const batch = writeBatch(ownerDb);
      batch.set(doc(collection(ownerDb, 'sessions', SESSION, 'matches')), {
        ownerUid: OWNER, courtId: 'court-1',
        teamA: ['p1', 'p2'], teamB: ['p3', 'p4'],
        scoreA: null, scoreB: null, startedAt: ts(), endedAt: null,
      });
      batch.update(doc(ownerDb, 'sessions', SESSION), {
        status: 'live', updatedAt: ts(),
      });
      return assertSucceeds(batch.commit());
    });

  // LIST QUERIES — the blind spot that shipped a broken app.
  //
  // Every check above reads a single document. But the app reads
  // COLLECTIONS, and rules behave differently there: a rule resting on
  // resource.data.ownerUid cannot be proven for a whole collection, so
  // Firestore rejects the entire query rather than filtering it. The
  // query must therefore repeat the rule's condition itself.
  //
  // Unfiltered = denied. Filtered = allowed. Both are asserted, because
  // only testing the happy path is what let this through the first time.
  for (const sub of ['players', 'courts', 'matches', 'bill']) {
    await check(`listing ${sub} WITHOUT an ownerUid filter is denied`, () =>
      assertFails(getDocs(collection(ownerDb, 'sessions', SESSION, sub))));

    await check(`listing ${sub} WITH an ownerUid filter is allowed`, () =>
      assertSucceeds(getDocs(query(
        collection(ownerDb, 'sessions', SESSION, sub),
        where('ownerUid', '==', OWNER),
      ))));
  }

  await check('listing club members WITHOUT a filter is denied', () =>
    assertFails(getDocs(collection(ownerDb, 'clubs', CLUB, 'members'))));
  await check('listing club members WITH an ownerUid filter is allowed', () =>
    assertSucceeds(getDocs(query(
      collection(ownerDb, 'clubs', CLUB, 'members'),
      where('ownerUid', '==', OWNER),
    ))));

  // Filtering by someone else's uid must not become a loophole.
  await check('filtering a list by another QM uid is denied', () =>
    assertFails(getDocs(query(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      where('ownerUid', '==', INTRUDER),
    ))));

  console.log('\n3. Another QM cannot touch this data');
  await check('intruder cannot read the session', () =>
    assertFails(getDoc(doc(intruderDb, 'sessions', SESSION))));
  await check('intruder cannot update the session', () =>
    assertFails(updateDoc(doc(intruderDb, 'sessions', SESSION), {
      title: 'hijacked',
      updatedAt: ts(),
    })));
  await check('intruder cannot delete the session', () =>
    assertFails(deleteDoc(doc(intruderDb, 'sessions', SESSION))));
  await check('intruder cannot add a player to it', () =>
    assertFails(addDoc(
      collection(intruderDb, 'sessions', SESSION, 'players'), validPlayer())));
  await check('intruder cannot read the roster', () =>
    assertFails(getDoc(
      doc(intruderDb, 'sessions', SESSION, 'players', 'anything'))));
  await check('intruder cannot read the club members', () =>
    assertFails(getDoc(doc(intruderDb, 'clubs', CLUB, 'members', 'anyone'))));
  await check('intruder cannot read or rewrite the bill', () =>
    assertFails(setDoc(doc(intruderDb, 'sessions', SESSION, 'bill', 'p1'), {
      ownerUid: OWNER, name: 'Jun',
      courtShareCentavos: 1, shuttleShareCentavos: 0,
    })));
  await check('nobody can create a session owned by someone else', () =>
    assertFails(addDoc(
      collection(intruderDb, 'sessions'), validSession(OWNER))));
  // Ownership now lives on the child itself, so it must be forgery-proof.
  await check('a child document cannot be stamped with another QM uid', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ ownerUid: INTRUDER }))));

  // The blind spot that broke club creation: every club check assumed a
  // club already existed (the seed writes one with rules disabled). The app
  // CREATES a club on the QM's first session, and that document has no
  // gcashNumber — reading a missing field in rules is an error, not null,
  // so the create was denied and every later club write failed with it.
  await check('owner creates a club with NO gcashNumber field', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'clubs'), {
      name: "Alice's club",
      ownerUid: OWNER,
      createdAt: ts(),
    })));
  await check('owner creates a club WITH a gcashNumber', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'clubs'), {
      name: "Alice's second club",
      ownerUid: OWNER,
      gcashNumber: '09293656299',
      createdAt: ts(),
    })));
  await check('owner can set a GCash number on their club', () =>
    assertSucceeds(updateDoc(doc(ownerDb, 'clubs', CLUB), {
      gcashNumber: '09293656299',
    })));
  await check('an over-long GCash value is rejected', () =>
    assertFails(updateDoc(doc(ownerDb, 'clubs', CLUB), {
      gcashNumber: '0'.repeat(200),
    })));
  await check('another QM cannot set your GCash number', () =>
    assertFails(updateDoc(doc(intruderDb, 'clubs', CLUB), {
      gcashNumber: '09999999999',
    })));

  console.log('\n4. Immutable fields stay immutable');
  await check('ownerUid cannot be reassigned', () =>
    assertFails(updateDoc(doc(ownerDb, 'sessions', SESSION), {
      ownerUid: INTRUDER,
      updatedAt: ts(),
    })));
  await check('createdAt cannot be rewritten', () =>
    assertFails(updateDoc(doc(ownerDb, 'sessions', SESSION), {
      createdAt: ts(new Date(2000, 0, 1)),
      updatedAt: ts(),
    })));

  console.log('\n5. Bad data is rejected — R-11');
  await check('negative gamesPlayed is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ gamesPlayed: -999 }))));
  await check('a nonsense player status is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ status: 'superstar' }))));
  await check('an invalid skill tier is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ skillTier: 'godlike' }))));
  await check('a huge name is rejected (storage abuse)', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ name: 'x'.repeat(5000) }))));
  await check('an empty name is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ name: '' }))));
  await check('unknown fields are rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ isAdmin: true }))));
  await check('gamesPlayed as a string is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ gamesPlayed: '5' }))));
  await check('negative money is rejected', () =>
    assertFails(addDoc(collection(ownerDb, 'sessions'), {
      ...validSession(), courtFeeCentavos: -50000 })));
  await check('an absurd court count is rejected', () =>
    assertFails(addDoc(collection(ownerDb, 'sessions'), {
      ...validSession(), courtCount: 9999 })));
  await check('zero courts is rejected', () =>
    assertFails(addDoc(collection(ownerDb, 'sessions'), {
      ...validSession(), courtCount: 0 })));
  await check('an invalid fee mode is rejected', () =>
    assertFails(addDoc(collection(ownerDb, 'sessions'), {
      ...validSession(), feeMode: 'free_for_all' })));
  // Ang per-game ay ang hatian ayon sa bilang ng laro. Kung hindi ito
  // nakadeploy sa rules, tahimik na babagsak ang pag-save ng QM.
  await check('the per-game fee mode is accepted', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'sessions'), {
      ...validSession(), feeMode: 'per_game' })));

  // -------------------------------------------------------------------------
  // Ang mga bagong field ay OPTIONAL - ito ang pinaka-mahalagang pagsubok
  // dito para sa isang app na may totoo nang gumagamit.
  //
  // May QM na nasa naka-cache na web build. Kung ang bagong rules ay
  // HIHINGI ng field na hindi pa alam ng build niya, bawat pagsulat niya
  // ay tatanggihan sa gitna ng gabi - at mukhang nasira ang app nang
  // hindi siya naglagay ng anuman. Kaya: tanggap ang luma AT ang bago.
  // -------------------------------------------------------------------------
  await check('a player without avatarSeed is accepted (old client)', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'), validPlayer())));
  await check('a player with avatarSeed is accepted (new client)', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ avatarSeed: 839188941 }))));
  await check('a null avatarSeed is accepted (means: from the name)', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ avatarSeed: null }))));
  await check('a negative avatarSeed is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ avatarSeed: -1 }))));
  await check('an avatarSeed that is not a number is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ avatarSeed: 'maricel' }))));

  await check('a player without gamesAtJoin is accepted (old client)', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'), validPlayer())));
  await check('a player with gamesAtJoin is accepted (new client)', () =>
    assertSucceeds(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ gamesPlayed: 7, gamesAtJoin: 3 }))));
  await check('a negative gamesAtJoin is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ gamesAtJoin: -2 }))));
  await check('an absurd gamesAtJoin is rejected', () =>
    assertFails(addDoc(
      collection(ownerDb, 'sessions', SESSION, 'players'),
      validPlayer({ gamesAtJoin: 99999 }))));

  await check('a bill line without gamesPlayed is accepted (old client)', () =>
    assertSucceeds(setDoc(doc(ownerDb, 'sessions', SESSION, 'bill', 'p9'), {
      ownerUid: OWNER, name: 'Jun',
      courtShareCentavos: 30000, shuttleShareCentavos: 0 })));
  await check('a bill line with gamesPlayed is accepted (new client)', () =>
    assertSucceeds(setDoc(doc(ownerDb, 'sessions', SESSION, 'bill', 'p9'), {
      ownerUid: OWNER, name: 'Jun',
      courtShareCentavos: 30000, shuttleShareCentavos: 0,
      gamesPlayed: 8 })));
  await check('a negative gamesPlayed on a bill line is rejected', () =>
    assertFails(setDoc(doc(ownerDb, 'sessions', SESSION, 'bill', 'p9'), {
      ownerUid: OWNER, name: 'Jun',
      courtShareCentavos: 30000, shuttleShareCentavos: 0,
      gamesPlayed: -3 })));
  await check('a match with three players per side is rejected', () =>
    assertFails(addDoc(collection(ownerDb, 'sessions', SESSION, 'matches'), {
      courtId: 'court-1',
      teamA: ['p1', 'p2', 'p3'],
      teamB: ['p4', 'p5', 'p6'],
      scoreA: null, scoreB: null, startedAt: ts(), endedAt: null,
    })));
  await check('a negative amount on a bill line is rejected', () =>
    assertFails(setDoc(doc(ownerDb, 'sessions', SESSION, 'bill', 'p2'), {
      ownerUid: OWNER, name: 'Jun',
      courtShareCentavos: -30000, shuttleShareCentavos: 0,
    })));
  await check('an unknown field on a bill line is rejected', () =>
    assertFails(setDoc(doc(ownerDb, 'sessions', SESSION, 'bill', 'p3'), {
      ownerUid: OWNER, name: 'Jun',
      courtShareCentavos: 100, shuttleShareCentavos: 0, discount: true,
    })));
  await check('a role other than qm is rejected', () =>
    assertFails(setDoc(doc(ownerDb, 'users', OWNER), {
      displayName: 'Alice', email: 'a@b.com', role: 'admin', createdAt: ts(),
    })));

  console.log('\n6. Money can go negative only where it should');
  await check('a member carry-over balance may be negative (overpaid)', () =>
    assertSucceeds(addDoc(collection(ownerDb, 'clubs', CLUB, 'members'), {
      ownerUid: OWNER, name: 'Ana', skillTier: 'beginner', aliases: [],
      balanceCentavos: -5000, sessionsAttended: 3,
      lastPlayedAt: null, createdAt: ts(),
    })));

  await env.cleanup();

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} rules checks passed`);
  if (failed.length > 0) {
    console.log('\nFailures:');
    for (const f of failed) console.log(`  - ${f.name}`);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
