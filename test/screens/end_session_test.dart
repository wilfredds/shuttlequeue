/// Ang gabing hindi matapos-tapos.
///
/// GALING ITO SA TOTOONG PAGSUBOK, hindi sa review. Sinubukan ng isang
/// kalaro ang app at wala siyang nakitang paraan para tapusin ang session.
/// Mayroon pala — ang "Lock the amounts" sa Money tab — pero hindi iyon ang
/// tinatanong niya, kaya hindi niya ito nakita. Ang resulta: nanatiling
/// `live` ang session magpakailanman, at ang oras ng paghihintay ng bawat
/// tao ay patuloy na lumaki hanggang sa maging walang kahulugan.
///
/// Dalawang bagay ang sinusubok dito, at pareho silang tungkol sa daloy at
/// hindi sa kalkulasyon:
///
///   1. May paraan ba talaga siyang tapusin ang gabi, at tumatama ba ito sa
///      Firestore?
///   2. Kapag tapos na, huminto na ba ang orasan?
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/models/bill_line.dart';
import 'package:shuttlequeue/models/court.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/models/synced.dart';
import 'package:shuttlequeue/providers/auth_providers.dart';
import 'package:shuttlequeue/providers/firebase_providers.dart';
import 'package:shuttlequeue/providers/session_providers.dart';
import 'package:shuttlequeue/screens/courts_screen.dart';
import 'package:shuttlequeue/screens/recap_screen.dart';
import 'package:shuttlequeue/screens/session_detail_screen.dart';

const _sessionId = 's1';
final _date = DateTime(2026, 10, 21, 20);

Session _session({SessionStatus status = SessionStatus.live}) => Session(
      id: _sessionId,
      ownerUid: 'qm',
      clubId: 'c1',
      title: 'Huwebes Palo',
      venue: 'Yspacio, Alapan',
      sessionDate: _date,
      status: status,
      courtCount: 2,
      courtFeeCentavos: 120000,
      shuttlePriceCentavos: 10000,
      feeMode: FeeMode.perGame,
      createdAt: _date,
      updatedAt: _date,
    );

/// Sinasadyang matagal na ang `waitingSince`: ito mismo ang reklamo.
SessionPlayer _player(String name, {PlayerStatus status = PlayerStatus.queued}) =>
    SessionPlayer(
      id: 'id-$name',
      name: name,
      skillTier: SkillTier.intermediate,
      gamesPlayed: 2,
      waitingSince: _date.subtract(const Duration(hours: 14)),
      status: status,
      shuttlesUsed: 0,
      hasPaid: false,
      createdAt: _date,
    );

final _roster = [
  _player('Maricel'),
  _player('Jhun'),
  _player('Bea'),
  _player('Rico'),
  _player('Neneng'),
];

const _freeCourts = [
  Court(id: 'c1', label: 'Court 1', status: CourtStatus.free),
  Court(id: 'c2', label: 'Court 2', status: CourtStatus.free),
];

const _busyCourts = [
  Court(
    id: 'c1',
    label: 'Court 1',
    status: CourtStatus.playing,
    currentMatchId: 'g1',
  ),
  Court(id: 'c2', label: 'Court 2', status: CourtStatus.free),
];

final _finishedMatch = [
  GameMatch(
    id: 'g0',
    courtId: 'c1',
    teamA: const ['id-Maricel', 'id-Jhun'],
    teamB: const ['id-Bea', 'id-Rico'],
    startedAt: _date.subtract(const Duration(minutes: 30)),
    endedAt: _date.subtract(const Duration(minutes: 16)),
  ),
];

final _liveMatch = [
  GameMatch(
    id: 'g1',
    courtId: 'c1',
    teamA: const ['id-Maricel', 'id-Jhun'],
    teamB: const ['id-Bea', 'id-Rico'],
    startedAt: _date,
  ),
];

/// Ibinabalik ang fake Firestore para matingnan kung ano talaga ang naisulat.
Future<FakeFirebaseFirestore> _pump(
  WidgetTester tester,
  Widget screen, {
  Session? session,
  List<Court> courts = _freeCourts,
  List<GameMatch> matches = const [],
}) async {
  final db = FakeFirebaseFirestore();
  final current = session ?? _session();

  // Kailangang totoo ang dokumento para may ma-update ang repository.
  await db.collection('sessions').doc(_sessionId).set({
    'ownerUid': 'qm',
    'title': current.title,
    'status': current.status.value,
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'qm')),
        ),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(MockUser(uid: 'qm')),
        ),
        sessionProvider(_sessionId).overrideWith((ref) => Stream.value(current)),
        playersProvider(_sessionId)
            .overrideWith((ref) => Stream.value(Synced.settled(_roster))),
        courtsProvider(_sessionId)
            .overrideWith((ref) => Stream.value(Synced.settled(courts))),
        matchesProvider(_sessionId).overrideWith((ref) => Stream.value(matches)),
        billProvider(_sessionId)
            .overrideWith((ref) => Stream.value(const <BillLine>[])),
        sessionsProvider.overrideWith(
          (ref) => Stream.value(Synced.settled([current])),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Ang bawat hilera sa roster ay may sarili ring more_vert, kaya hindi
/// sapat ang icon lang.
final Finder _sessionMenu = find.descendant(
  of: find.byType(AppBar),
  matching: find.byIcon(Icons.more_vert),
);

Future<String?> _statusIn(FakeFirebaseFirestore db) async {
  final doc = await db.collection('sessions').doc(_sessionId).get();
  return doc.data()?['status'] as String?;
}

void main() {
  group('may paraan bang tapusin ang gabi', () {
    testWidgets('nahahanap ito nang hindi dumadaan sa Money tab',
        (tester) async {
      await _pump(tester, const SessionDetailScreen(sessionId: _sessionId));

      await tester.tap(_sessionMenu);
      await tester.pumpAndSettle();

      expect(find.text('End session'), findsOneWidget);
    });

    testWidgets('tumatama ito sa Firestore, hindi lang sa screen',
        (tester) async {
      final db =
          await _pump(tester, const SessionDetailScreen(sessionId: _sessionId));
      expect(await _statusIn(db), 'live');

      await tester.tap(_sessionMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();

      // May kumpirmasyon — ang pagtatapos ng gabi ay hindi dapat aksidente.
      expect(find.text('End tonight?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'End session'));
      await tester.pumpAndSettle();

      expect(await _statusIn(db), 'ended');
    });

    testWidgets('mapipigilan ito bago makumpirma', (tester) async {
      final db =
          await _pump(tester, const SessionDetailScreen(sessionId: _sessionId));

      await tester.tap(_sessionMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(await _statusIn(db), 'live');
    });

    testWidgets('hindi matatapos habang may naglalaro', (tester) async {
      // Ang pagtatapos ng laro ay nagdaragdag ng isa sa bilang ng apat na
      // tao, at sa per-game ay pera iyon. Walang pindutang "tapusin ang
      // gabi" ang dapat tahimik na nagbabago ng singil ng kahit sino.
      final db = await _pump(
        tester,
        const SessionDetailScreen(sessionId: _sessionId),
        courts: _busyCourts,
        matches: _liveMatch,
      );

      await tester.tap(_sessionMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();

      // Walang dialog — sinasabi nito kung aling court, at tumitigil doon.
      expect(find.text('End tonight?'), findsNothing);
      expect(find.textContaining('Court 1'), findsWidgets);
      expect(await _statusIn(db), 'live');
    });

    testWidgets('ang tapos nang gabi ay maibabalik', (tester) async {
      final db = await _pump(
        tester,
        const SessionDetailScreen(sessionId: _sessionId),
        session: _session(status: SessionStatus.ended),
      );

      await tester.tap(_sessionMenu);
      await tester.pumpAndSettle();
      expect(find.text('End session'), findsNothing);

      await tester.tap(find.text('Reopen session'));
      await tester.pumpAndSettle();

      expect(await _statusIn(db), 'live');
    });

    testWidgets('sinasabi ng header kung tapos na', (tester) async {
      await _pump(
        tester,
        const SessionDetailScreen(sessionId: _sessionId),
        session: _session(status: SessionStatus.ended),
      );
      expect(find.text('ENDED'), findsOneWidget);
    });
  });

  group('nakikita ba ito kung saan siya nakaupo', () {
    // Ang menu sa app bar ang nakasanayang lugar, pero ang Recap ang
    // screen na binubuksan niya kapag tapos na ang gabi. Dalawang pasukan,
    // iisang kodigo.
    testWidgets('may End session sa dulo ng Recap habang bukas pa',
        (tester) async {
      await _pump(
        tester,
        const RecapScreen(sessionId: _sessionId),
        matches: _finishedMatch,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'End session'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'End session'),
        findsOneWidget,
      );
    });

    testWidgets('wala na ito kapag tapos na ang gabi', (tester) async {
      await _pump(
        tester,
        const RecapScreen(sessionId: _sessionId),
        session: _session(status: SessionStatus.ended),
        matches: _finishedMatch,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'End session'),
        findsNothing,
      );
    });
  });

  group('huminto ba ang orasan', () {
    testWidgets('habang live, lumalaki ang hintay — ito ang reklamo',
        (tester) async {
      await _pump(tester, const CourtsScreen(sessionId: _sessionId));

      // Umaandar ang orasan: may oras ng paghihintay sa tabi ng pangalan.
      expect(find.textContaining('m wait'), findsWidgets);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('kapag tapos na, gitling na lang — walang lumalaking bilang',
        (tester) async {
      await _pump(
        tester,
        const CourtsScreen(sessionId: _sessionId),
        session: _session(status: SessionStatus.ended),
      );

      // Huminto na: walang umaandar na bilang, gitling na lang.
      expect(find.textContaining('m wait'), findsNothing);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('kapag tapos na, hindi na puwedeng magsimula ng laro',
        (tester) async {
      await _pump(
        tester,
        const CourtsScreen(sessionId: _sessionId),
        session: _session(status: SessionStatus.ended),
      );

      // Sinasabi kung bakit, hindi lang naka-dim.
      expect(
        find.text('Reopen the session if people are still playing.'),
        findsOneWidget,
      );
    });
  });
}
