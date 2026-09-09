import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/models/bill_line.dart';
import 'package:shuttlequeue/models/club_member.dart';
import 'package:shuttlequeue/models/court.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/models/synced.dart';
import 'package:shuttlequeue/providers/auth_providers.dart';
import 'package:shuttlequeue/providers/firebase_providers.dart';
import 'package:shuttlequeue/providers/session_providers.dart';
import 'package:shuttlequeue/screens/board_screen.dart';
import 'package:shuttlequeue/screens/courts_screen.dart';
import 'package:shuttlequeue/screens/import_screen.dart';
import 'package:shuttlequeue/screens/regulars_screen.dart';
import 'package:shuttlequeue/screens/roster_screen.dart';
import 'package:shuttlequeue/screens/session_detail_screen.dart';
import 'package:shuttlequeue/screens/session_form_screen.dart';

/// Isang tanong lang ang sinasagot ng file na ito, at ito ang tanong na
/// itinanong mismo ni France noong nasira ang app:
///
///     "may pinindot ako, walang lumabas."
///
/// Bawat screen dito ay pinapatakbo nang totoo, may datos, at tinitingnan
/// kung may LUMALABAS BA. Hindi nito sinusukat ang tamang kuwenta — may
/// sariling test ang mga iyon. Ito ay laban sa blangkong screen, sa
/// walang katapusang spinner, at sa exception habang nagbu-build.
const _sessionId = 's1';
final _date = DateTime(2026, 9, 8, 20);

Session _session({
  SessionStatus status = SessionStatus.live,
  DateTime? finalizedAt,
}) =>
    Session(
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
      feeMode: FeeMode.perHead,
      createdAt: _date,
      updatedAt: _date,
      billFinalizedAt: finalizedAt,
    );

SessionPlayer _player(
  String name, {
  int games = 0,
  PlayerStatus status = PlayerStatus.queued,
  SkillTier tier = SkillTier.intermediate,
}) =>
    SessionPlayer(
      id: 'id-$name',
      name: name,
      skillTier: tier,
      gamesPlayed: games,
      waitingSince: _date,
      status: status,
      shuttlesUsed: 0,
      hasPaid: false,
      createdAt: _date,
    );

ClubMember _member(String name) => ClubMember(
      id: 'm-$name',
      name: name,
      skillTier: SkillTier.advanced,
      aliases: const [],
      sessionsAttended: 4,
      balanceCentavos: 0,
      createdAt: _date,
    );

final _roster = [
  _player('Ana', games: 2),
  _player('Ben', games: 2, status: PlayerStatus.playing),
  _player('Carlo', games: 1),
  _player('Dina', games: 1, status: PlayerStatus.playing),
  _player('Emman'),
  _player('Niña', tier: SkillTier.beginner),
];

final _courts = [
  const Court(id: 'c1', label: 'Court 1', status: CourtStatus.playing,
      currentMatchId: 'g1'),
  const Court(id: 'c2', label: 'Court 2', status: CourtStatus.free),
];

final _matches = [
  GameMatch(
    id: 'g1',
    courtId: 'c1',
    teamA: const ['id-Ben', 'id-Dina'],
    teamB: const ['id-Ana', 'id-Carlo'],
    startedAt: _date,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Session? session,
  List<SessionPlayer>? players,
  List<ClubMember> members = const [],
  List<BillLine> bill = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'qm')),
        ),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(
            MockUser(uid: 'qm', displayName: 'France'),
          ),
        ),
        sessionProvider(_sessionId)
            .overrideWith((ref) => Stream.value(session ?? _session())),
        playersProvider(_sessionId).overrideWith(
          (ref) => Stream.value(Synced.settled(players ?? _roster)),
        ),
        courtsProvider(_sessionId)
            .overrideWith((ref) => Stream.value(Synced.settled(_courts))),
        matchesProvider(_sessionId)
            .overrideWith((ref) => Stream.value(_matches)),
        billProvider(_sessionId).overrideWith((ref) => Stream.value(bill)),
        clubMembersProvider.overrideWith((ref) => Stream.value(members)),
        sessionsProvider.overrideWith(
          (ref) => Stream.value(Synced.settled([_session()])),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Walang katapusang animation ang ilang screen (hal. ang tumitibok
        // na LIVE). Hindi natatapos ang pumpAndSettle kapag ganoon.
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
}

void main() {
  group('Roster', () {
    testWidgets('nakikita ang bawat manlalaro', (tester) async {
      await _pump(tester, const RosterScreen(sessionId: _sessionId));

      for (final name in ['Ana', 'Ben', 'Carlo', 'Dina', 'Emman', 'Niña']) {
        expect(find.text(name), findsWidgets, reason: 'nawawala si $name');
      }
    });

    testWidgets('walang manlalaro pa: may paliwanag, hindi blangko',
        (tester) async {
      await _pump(
        tester,
        const RosterScreen(sessionId: _sessionId),
        players: const [],
      );

      expect(find.byType(Text), findsWidgets);
    });
  });

  group('Courts', () {
    testWidgets('nakikita ang mga court at ang pila', (tester) async {
      await _pump(tester, const CourtsScreen(sessionId: _sessionId));

      expect(find.textContaining('Court 1'), findsWidgets);
      expect(find.textContaining('Court 2'), findsWidgets);
      // Ang naglalaro ay nasa court, hindi sa pila.
      expect(find.text('Ben'), findsWidgets);
    });

    testWidgets('walang court pa: hindi nagsisinungaling tungkol dito',
        (tester) async {
      // Habang naglo-load, dati ay sinasabi nitong "All courts are playing"
      // — kasinungalingan iyon tungkol sa isang walang lamang listahan.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            firebaseAuthProvider.overrideWithValue(
              MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'qm')),
            ),
            sessionProvider(_sessionId)
                .overrideWith((ref) => Stream.value(_session())),
            playersProvider(_sessionId).overrideWith(
              (ref) => Stream.value(Synced.settled(_roster)),
            ),
            courtsProvider(_sessionId).overrideWith(
              (ref) => Stream.value(const Synced.settled(<Court>[])),
            ),
            matchesProvider(_sessionId)
                .overrideWith((ref) => Stream.value(const <GameMatch>[])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CourtsScreen(sessionId: _sessionId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All courts are playing'), findsNothing);
    });
  });

  group('Board — ang pangalawang screen sa gym', () {
    testWidgets('nakikita ang mga pangalan mula sa malayo', (tester) async {
      await _pump(tester, const BoardScreen(sessionId: _sessionId));

      expect(find.text('Ana'), findsWidgets);
      expect(find.text('Ben'), findsWidgets);
    });

    testWidgets('R-16: walang skill tier sa harap ng lahat', (tester) async {
      // Nakikita ito ng buong hall. Ang "Niña — Beginner" ay hindi
      // impormasyon, kahihiyan iyon.
      await _pump(tester, const BoardScreen(sessionId: _sessionId));

      for (final tier in ['Beginner', 'Intermediate', 'Advanced']) {
        expect(find.textContaining(tier), findsNothing, reason: tier);
      }
    });
  });

  group('Regulars', () {
    testWidgets('nakikita ang libro', (tester) async {
      await _pump(
        tester,
        const RegularsScreen(),
        members: [_member('Ana'), _member('Kuya Jun')],
      );

      expect(find.text('Ana'), findsWidgets);
      expect(find.text('Kuya Jun'), findsWidgets);
    });

    testWidgets('walang laman pa: hindi blangko', (tester) async {
      await _pump(tester, const RegularsScreen());
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('Import', () {
    testWidgets('may mapagpapastehan agad', (tester) async {
      await _pump(tester, const ImportScreen(sessionId: _sessionId));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('ang pinaste ay nagiging listahan ng pangalan',
        (tester) async {
      await _pump(tester, const ImportScreen(sessionId: _sessionId));

      await tester.enterText(
        find.byType(TextField).first,
        'Thursday 8pm\n1. Mark\n2. Ana - paid\n3. Kuya Jun +1',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Mark'), findsWidgets);
      expect(find.textContaining('Ana'), findsWidgets);
    });
  });

  group('Session detail — ang apat na tab', () {
    testWidgets('bumubukas at may laman ang unang tab', (tester) async {
      await _pump(tester, const SessionDetailScreen(sessionId: _sessionId));

      expect(find.text('Huwebes Palo'), findsWidgets);
      expect(find.text('Ana'), findsWidgets);
    });

    testWidgets('nariyan ang apat na tab', (tester) async {
      await _pump(tester, const SessionDetailScreen(sessionId: _sessionId));

      for (final tab in ['Roster', 'Courts', 'Money', 'Recap']) {
        expect(find.text(tab), findsWidgets, reason: 'nawawala ang $tab');
      }
    });
  });

  group('Session form', () {
    testWidgets('bagong gabi: may mapupunan', (tester) async {
      await _pump(tester, const SessionFormScreen());
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('pag-edit: nakalagay na ang mga dating detalye',
        (tester) async {
      await _pump(tester, SessionFormScreen(existing: _session()));
      expect(find.text('Huwebes Palo'), findsWidgets);
    });

    testWidgets('template: kopya ng detalye, bagong petsa', (tester) async {
      await _pump(tester, SessionFormScreen(template: _session()));
      expect(find.text('Huwebes Palo'), findsWidgets);
    });
  });
}
