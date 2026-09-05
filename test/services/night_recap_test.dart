import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/night_recap.dart';

final _start = DateTime(2026, 7, 6, 20);

SessionPlayer player(
  String name, {
  int games = 0,
  int shuttles = 0,
  DateTime? arrived,
}) {
  return SessionPlayer(
    id: 'id-$name',
    name: name,
    skillTier: SkillTier.intermediate,
    gamesPlayed: games,
    waitingSince: _start,
    status: PlayerStatus.queued,
    shuttlesUsed: shuttles,
    hasPaid: false,
    createdAt: arrived ?? _start,
  );
}

/// Isang tapos na laro, `afterMinutes` matapos ang simula ng gabi.
GameMatch match(
  List<String> teamA,
  List<String> teamB, {
  required int afterMinutes,
  int lengthMinutes = 12,
}) {
  final began = _start.add(Duration(minutes: afterMinutes));
  return GameMatch(
    id: '${teamA.join()}-${teamB.join()}-$afterMinutes',
    courtId: 'c1',
    teamA: teamA.map((n) => 'id-$n').toList(),
    teamB: teamB.map((n) => 'id-$n').toList(),
    startedAt: began,
    endedAt: began.add(Duration(minutes: lengthMinutes)),
  );
}

GameMatch inProgress(List<String> teamA, List<String> teamB) {
  return GameMatch(
    id: 'live',
    courtId: 'c2',
    teamA: teamA.map((n) => 'id-$n').toList(),
    teamB: teamB.map((n) => 'id-$n').toList(),
    startedAt: _start.add(const Duration(minutes: 90)),
  );
}

PlayerRecap recapFor(NightRecap recap, String name) =>
    recap.players.firstWhere((p) => p.name == name);

void main() {
  group('partner and opponent variety', () {
    test('counts distinct partners and opponents across the night', () {
      final players = [
        player('Ana', games: 2),
        player('Ben', games: 2),
        player('Carl', games: 2),
        player('Dina', games: 2),
        player('Elmo', games: 1),
      ];
      final matches = [
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 0),
        match(['Ana', 'Carl'], ['Ben', 'Elmo'], afterMinutes: 20),
      ];

      final recap = buildNightRecap(players: players, matches: matches);
      final ana = recapFor(recap, 'Ana');

      // Ana teamed with Ben, then Carl.
      expect(ana.distinctPartners, 2);
      // She faced Carl and Dina, then Ben and Elmo.
      expect(ana.distinctOpponents, 4);
    });

    test('a repeated pairing is counted once as a distinct partner', () {
      final players = [
        player('Ana', games: 2),
        player('Ben', games: 2),
        player('Carl', games: 2),
        player('Dina', games: 2),
      ];
      final matches = [
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 0),
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 20),
      ];

      final ana = recapFor(
        buildNightRecap(players: players, matches: matches),
        'Ana',
      );
      expect(ana.distinctPartners, 1);
      expect(ana.mostFrequentPartner, 'Ben');
      expect(ana.mostFrequentPartnerCount, 2);
    });

    test('the most frequent partner is stable when counts tie', () {
      final players = [
        player('Ana', games: 2),
        player('Ben', games: 1),
        player('Zoe', games: 1),
        player('Carl', games: 2),
        player('Dina', games: 2),
      ];
      final matches = [
        match(['Ana', 'Zoe'], ['Carl', 'Dina'], afterMinutes: 0),
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 20),
      ];

      // Both partners appear once — the name breaks the tie, so the
      // answer never flickers between rebuilds.
      final ana = recapFor(
        buildNightRecap(players: players, matches: matches),
        'Ana',
      );
      expect(ana.mostFrequentPartner, 'Ben');
    });
  });

  group('games and shuttles come from the player document', () {
    test('gamesPlayed is the fairness counter, not a count of match rows', () {
      // Sinasadya ang hindi pagtutugma: ang doc ang opisyal na bilang.
      final players = [player('Ana', games: 7, shuttles: 3)];
      final recap = buildNightRecap(players: players, matches: const []);

      expect(recapFor(recap, 'Ana').gamesPlayed, 7);
      expect(recapFor(recap, 'Ana').shuttlesUsed, 3);
    });

    test('night totals add up', () {
      final players = [
        player('Ana', games: 1, shuttles: 2),
        player('Ben', games: 1, shuttles: 1),
        player('Carl', games: 1),
        player('Dina', games: 1),
      ];
      final matches = [
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 0),
      ];

      final recap = buildNightRecap(players: players, matches: matches);
      expect(recap.totalGames, 1);
      expect(recap.totalShuttles, 3);
      expect(recap.playerCount, 4);
      expect(recap.playersWhoPlayed, 4);
    });
  });

  group('in-progress matches are excluded', () {
    test('a live match does not count toward totals or partner stats', () {
      final players = [
        player('Ana', games: 1),
        player('Ben', games: 1),
        player('Carl', games: 1),
        player('Dina', games: 1),
        player('Elmo'),
        player('Fely'),
      ];
      final matches = [
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 0),
        inProgress(['Ana', 'Elmo'], ['Fely', 'Ben']),
      ];

      final recap = buildNightRecap(players: players, matches: matches);
      expect(recap.totalGames, 1, reason: 'the live match is not finished');

      // Elmo is on court right now but has no completed game yet.
      final elmo = recapFor(recap, 'Elmo');
      expect(elmo.distinctPartners, 0);
      expect(elmo.didPlay, isFalse);
    });
  });

  group('longest wait', () {
    test('measures the gap between a finished game and the next one', () {
      final players = [
        player('Ana', games: 2),
        player('Ben', games: 2),
        player('Carl', games: 2),
        player('Dina', games: 2),
      ];
      // First game 0–12, second starts at 50 → a 38 minute wait.
      final matches = [
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 0),
        match(['Ana', 'Ben'], ['Carl', 'Dina'], afterMinutes: 50),
      ];

      final ana = recapFor(
        buildNightRecap(players: players, matches: matches),
        'Ana',
      );
      expect(ana.longestWait, const Duration(minutes: 38));
    });

    test('counts the wait from arriving to the first game', () {
      // Dumating si Ana sa simula, pero 45 minuto bago siya nakalaro.
      final players = [player('Ana', games: 1), player('Ben', games: 1)];
      final matches = [
        match(['Ana', 'Ben'], ['X', 'Y'], afterMinutes: 45),
      ];

      final ana = recapFor(
        buildNightRecap(players: players, matches: matches),
        'Ana',
      );
      expect(ana.longestWait, const Duration(minutes: 45));
    });

    test('a late arrival is not credited with waiting before they showed up',
        () {
      final players = [
        player('Late', games: 1, arrived: _start.add(const Duration(minutes: 60))),
      ];
      final matches = [
        match(['Late', 'X'], ['Y', 'Z'], afterMinutes: 70),
      ];

      final late = recapFor(
        buildNightRecap(players: players, matches: matches),
        'Late',
      );
      expect(late.longestWait, const Duration(minutes: 10));
    });

    test('is null for someone who never got on court', () {
      final recap = buildNightRecap(
        players: [player('Benchwarmer')],
        matches: const [],
      );
      expect(recapFor(recap, 'Benchwarmer').longestWait, isNull);
    });
  });

  group('session length', () {
    test('spans the first game start to the last game end', () {
      final players = [player('Ana', games: 2), player('Ben', games: 2)];
      final matches = [
        match(['Ana', 'Ben'], ['X', 'Y'], afterMinutes: 0, lengthMinutes: 12),
        match(['Ana', 'Ben'], ['X', 'Y'], afterMinutes: 100, lengthMinutes: 15),
      ];

      final recap = buildNightRecap(players: players, matches: matches);
      expect(recap.sessionLength, const Duration(minutes: 115));
    });

    test('is null before anyone finishes a game', () {
      final recap = buildNightRecap(
        players: [player('Ana')],
        matches: const [],
      );
      expect(recap.sessionLength, isNull);
    });
  });

  group('never breaks on messy real data', () {
    test('an empty session produces an empty recap, not a crash', () {
      final recap = buildNightRecap(players: const [], matches: const []);
      expect(recap.players, isEmpty);
      expect(recap.totalGames, 0);
      expect(recap.playersWhoPlayed, 0);
    });

    test('a match referencing a removed player is tolerated', () {
      final players = [player('Ana', games: 1)];
      final matches = [
        match(['Ana', 'Ghost'], ['Gone', 'Vanished'], afterMinutes: 0),
      ];

      final recap = buildNightRecap(players: players, matches: matches);
      final ana = recapFor(recap, 'Ana');

      // Nananatiling tama ang bilang kahit wala na ang ibang manlalaro.
      expect(ana.distinctPartners, 1);
      expect(ana.distinctOpponents, 2);
      // Walang pangalan, kaya ang ID na lang ang ipinapakita — hindi crash.
      expect(ana.mostFrequentPartner, isNotNull);
    });

    test('players are listed by name, never ranked by games played', () {
      final players = [
        player('Zoe', games: 9),
        player('Ana', games: 1),
        player('Mia', games: 5),
      ];
      final recap = buildNightRecap(players: players, matches: const []);

      expect(
        recap.players.map((p) => p.name).toList(),
        ['Ana', 'Mia', 'Zoe'],
        reason: 'a court-time leaderboard would start arguments',
      );
    });
  });
}
