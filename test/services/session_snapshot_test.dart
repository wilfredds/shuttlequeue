import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/court.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/session_snapshot.dart';

final _date = DateTime(2026, 7, 6, 20);
final _now = DateTime(2026, 7, 6, 22, 35);

Session session({
  int courtFee = 120000,
  int shuttlePrice = 10000,
  FeeMode mode = FeeMode.perHead,
}) {
  return Session(
    id: 's1',
    ownerUid: 'qm',
    clubId: 'c1',
    title: 'Monday Night Palo',
    venue: 'Yspacio, Alapan, Imus',
    sessionDate: _date,
    status: SessionStatus.live,
    courtCount: 2,
    courtFeeCentavos: courtFee,
    shuttlePriceCentavos: shuttlePrice,
    feeMode: mode,
    createdAt: _date,
    updatedAt: _date,
  );
}

SessionPlayer player(
  String name, {
  int games = 0,
  SkillTier tier = SkillTier.intermediate,
  PlayerStatus status = PlayerStatus.queued,
  int shuttles = 0,
  bool paid = false,
}) {
  return SessionPlayer(
    id: 'id-$name',
    name: name,
    skillTier: tier,
    gamesPlayed: games,
    waitingSince: _date,
    status: status,
    shuttlesUsed: shuttles,
    hasPaid: paid,
    createdAt: _date,
  );
}

void main() {
  group('the insurance policy — R-01', () {
    test('captures everything needed to rebuild the night on paper', () {
      final players = [
        player('Ana', games: 3, tier: SkillTier.advanced, paid: true),
        player('Ben', games: 2, shuttles: 2),
        player('Carl', games: 2, status: PlayerStatus.playing),
        player('Dina', games: 1, status: PlayerStatus.left),
      ];

      final text = buildSessionSnapshot(
        session: session(),
        players: players,
        courts: [
          const Court(id: 'c1', label: 'Court 1', status: CourtStatus.playing,
              currentMatchId: 'm1'),
          const Court(id: 'c2', label: 'Court 2', status: CourtStatus.free),
        ],
        matches: [
          GameMatch(
            id: 'm1',
            courtId: 'c1',
            teamA: ['id-Ana', 'id-Ben'],
            teamB: ['id-Carl', 'id-Dina'],
            startedAt: _now.subtract(const Duration(minutes: 10)),
          ),
          GameMatch(
            id: 'm0',
            courtId: 'c2',
            teamA: ['id-Ana', 'id-Carl'],
            teamB: ['id-Ben', 'id-Dina'],
            startedAt: _date,
            endedAt: _date.add(const Duration(minutes: 12)),
          ),
        ],
        now: _now,
      );

      // Kailan at saan
      expect(text, contains('Monday Night Palo'));
      expect(text, contains('Yspacio, Alapan, Imus'));
      expect(text, contains('Jul 6, 2026'));
      expect(text, contains('Snapshot:'));

      // Sino at ilan ang laro nila — ito ang batayan ng fairness
      expect(text, contains('Ana'));
      expect(text, contains('3 games'));
      expect(text, contains('1 game'), reason: 'singular, not "1 games"');

      // Anong nangyayari sa court ngayon
      expect(text, contains('Court 1: Ana & Ben vs Carl & Dina'));
      expect(text, contains('Court 2: free'));
      expect(text, contains('Games finished: 1'));
      expect(text, contains('Left early: Dina'));

      // Ang pera
      expect(text, contains('COST SPLIT (per head)'));
      expect(text, contains('PAID'));
      expect(text, contains('Total'));
    });

    test('sorts players by games played so unfairness is obvious', () {
      final text = buildSessionSnapshot(
        session: session(),
        players: [
          player('Low', games: 1),
          player('High', games: 9),
          player('Mid', games: 5),
        ],
        courts: const [],
        matches: const [],
        now: _now,
      );

      expect(text.indexOf('High'), lessThan(text.indexOf('Mid')));
      expect(text.indexOf('Mid'), lessThan(text.indexOf('Low')));
    });

    test('marks skill tier with a single letter', () {
      final text = buildSessionSnapshot(
        session: session(),
        players: [
          player('Adv', tier: SkillTier.advanced),
          player('Beg', tier: SkillTier.beginner),
        ],
        courts: const [],
        matches: const [],
        now: _now,
      );
      expect(text, contains('[A] Adv'));
      expect(text, contains('[B] Beg'));
    });

    test('american mode is labelled correctly', () {
      final text = buildSessionSnapshot(
        session: session(mode: FeeMode.american),
        players: [player('Ana'), player('Ben')],
        courts: const [],
        matches: const [],
        now: _now,
      );
      expect(text, contains('COST SPLIT (american)'));
    });
  });

  group('never breaks when the night has barely started', () {
    test('an empty session still produces a usable snapshot', () {
      final text = buildSessionSnapshot(
        session: session(),
        players: const [],
        courts: const [],
        matches: const [],
        now: _now,
      );
      expect(text, contains('Monday Night Palo'));
      expect(text, contains('PLAYERS (0)'));
      expect(text, contains('none yet'));
      expect(text, isNot(contains('COST SPLIT')));
    });

    test('a match referencing a removed player does not crash', () {
      final text = buildSessionSnapshot(
        session: session(),
        players: [player('Ana')],
        courts: [
          const Court(id: 'c1', label: 'Court 1', status: CourtStatus.playing,
              currentMatchId: 'm1'),
        ],
        matches: [
          GameMatch(
            id: 'm1',
            courtId: 'c1',
            teamA: ['id-Ana', 'deleted-player'],
            teamB: ['also-gone', 'still-gone'],
            startedAt: _now,
          ),
        ],
        now: _now,
      );
      expect(text, contains('Court 1: Ana vs ?'));
    });

    test('a venue-less session omits the venue line cleanly', () {
      final withoutVenue = Session(
        id: 's1', ownerUid: 'qm', clubId: '', title: 'Quick game',
        venue: '', sessionDate: _date, status: SessionStatus.setup,
        courtCount: 1, courtFeeCentavos: 0, shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead, createdAt: _date, updatedAt: _date,
      );
      final text = buildSessionSnapshot(
        session: withoutVenue,
        players: const [],
        courts: const [],
        matches: const [],
        now: _now,
      );
      expect(text, contains('Quick game'));
      expect(text.split('\n').where((l) => l.trim().isEmpty).length,
          greaterThan(0));
    });
  });
}
