import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/matchmaking_service.dart';

final _now = DateTime(2026, 7, 6, 21);

SessionPlayer player(
  String id, {
  int games = 0,
  SkillTier tier = SkillTier.intermediate,
  PlayerStatus status = PlayerStatus.queued,
  int waitingMinutes = 0,
}) {
  return SessionPlayer(
    id: id,
    name: id,
    skillTier: tier,
    gamesPlayed: games,
    waitingSince: _now.subtract(Duration(minutes: waitingMinutes)),
    status: status,
    shuttlesUsed: 0,
    hasPaid: false,
    createdAt: _now.subtract(const Duration(hours: 2)),
  );
}

GameMatch playedMatch(List<String> a, List<String> b) => GameMatch(
      id: '${a.join()}-${b.join()}',
      courtId: 'c1',
      teamA: a,
      teamB: b,
      startedAt: _now.subtract(const Duration(minutes: 30)),
      endedAt: _now.subtract(const Duration(minutes: 15)),
    );

void main() {
  const service = MatchmakingService();

  Set<String> idsOf(MatchSuggestion s) =>
      s.allPlayers.map((p) => p.id).toSet();

  group('eligibility', () {
    test('returns null when fewer than four are queued', () {
      final players = [player('a'), player('b'), player('c')];
      expect(
        service.suggestNext(players: players, now: _now),
        isNull,
      );
    });

    test('players who are playing, resting or left are never picked', () {
      final players = [
        player('queued1'),
        player('queued2'),
        player('queued3'),
        player('queued4'),
        player('onCourt', status: PlayerStatus.playing),
        player('resting', status: PlayerStatus.resting),
        player('wentHome', status: PlayerStatus.left),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(
        idsOf(suggestion),
        {'queued1', 'queued2', 'queued3', 'queued4'},
      );
    });

    test('four queued players with a leaver present still forms a match', () {
      final players = [
        player('a'),
        player('b'),
        player('c'),
        player('d'),
        player('gone', status: PlayerStatus.left),
      ];
      expect(service.suggestNext(players: players, now: _now), isNotNull);
    });
  });

  group('fairness — fewest games first', () {
    test('picks the four with the fewest games played', () {
      final players = [
        player('played3', games: 3),
        player('played0a'),
        player('played0b'),
        player('played0c'),
        player('played0d'),
        player('played2', games: 2),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(
        idsOf(suggestion),
        {'played0a', 'played0b', 'played0c', 'played0d'},
      );
    });

    test('ties on games are broken by who has waited longest', () {
      final players = [
        player('waited1', waitingMinutes: 1),
        player('waited20', waitingMinutes: 20),
        player('waited15', waitingMinutes: 15),
        player('waited10', waitingMinutes: 10),
        player('waited5', waitingMinutes: 5),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;
      // Ang isang minutong naghintay lang ang dapat maiwan.
      expect(idsOf(suggestion), isNot(contains('waited1')));
      expect(idsOf(suggestion), contains('waited20'));
    });

    test('queueOrder exposes the same ordering for the up-next list', () {
      final players = [
        player('c', games: 2),
        player('a', games: 0, waitingMinutes: 10),
        player('b', games: 0, waitingMinutes: 5),
      ];
      expect(
        queueOrder(players).map((p) => p.id).toList(),
        ['a', 'b', 'c'],
      );
    });
  });

  group('skill grouping', () {
    test('prefers players within one tier of each other', () {
      final players = [
        player('beg1', tier: SkillTier.beginner),
        player('beg2', tier: SkillTier.beginner),
        player('beg3', tier: SkillTier.beginner),
        player('beg4', tier: SkillTier.beginner),
        player('adv1', tier: SkillTier.advanced),
        player('adv2', tier: SkillTier.advanced),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(idsOf(suggestion), {'beg1', 'beg2', 'beg3', 'beg4'});
      expect(suggestion.isMixedSkill, isFalse);
    });

    test('falls back to a mixed match and flags it rather than blocking', () {
      // Isang beginner lang ang anchor at puro advanced ang iba.
      final players = [
        player('beg', tier: SkillTier.beginner),
        player('adv1', tier: SkillTier.advanced),
        player('adv2', tier: SkillTier.advanced),
        player('adv3', tier: SkillTier.advanced),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(suggestion, isNotNull);
      expect(suggestion.isMixedSkill, isTrue, reason: 'QM must see the warning');
      expect(idsOf(suggestion).length, 4);
    });
  });

  group('long-wait guarantee — the anti-starvation valve', () {
    test('a stranded player is force-promoted despite a bad tier fit', () {
      // Si "stranded" ay nag-iisang advanced: hindi siya kailanman
      // mapipili ng skill grouping. Pero 40 minuto na siyang naghihintay.
      final players = [
        player('stranded',
            tier: SkillTier.advanced, games: 1, waitingMinutes: 40),
        player('beg1', tier: SkillTier.beginner),
        player('beg2', tier: SkillTier.beginner),
        player('beg3', tier: SkillTier.beginner),
        player('beg4', tier: SkillTier.beginner),
        player('beg5', tier: SkillTier.beginner),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;

      expect(
        idsOf(suggestion),
        contains('stranded'),
        reason: 'nobody should sit out the whole night',
      );
      expect(
        suggestion.forcedByLongWait.map((p) => p.id),
        contains('stranded'),
      );
    });

    test('nobody is forced before the threshold', () {
      final players = [
        player('a', waitingMinutes: 5),
        player('b', waitingMinutes: 4),
        player('c', waitingMinutes: 3),
        player('d', waitingMinutes: 2),
      ];
      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(suggestion.forcedByLongWait, isEmpty);
    });
  });

  group('no-repeat rotation', () {
    test('prefers a combination that has not played together tonight', () {
      final players = [
        player('anchor', waitingMinutes: 30),
        player('freshA', waitingMinutes: 10),
        player('freshB', waitingMinutes: 9),
        player('freshC', waitingMinutes: 8),
        player('playedBefore1', waitingMinutes: 29),
        player('playedBefore2', waitingMinutes: 28),
        player('playedBefore3', waitingMinutes: 27),
      ];

      // Ang anchor ay kalalaro lang ng tatlong ito.
      final history = [
        playedMatch(
          ['anchor', 'playedBefore1'],
          ['playedBefore2', 'playedBefore3'],
        ),
      ];

      final suggestion = service.suggestNext(
        players: players,
        now: _now,
        history: history,
      )!;

      final chosen = idsOf(suggestion);
      final repeats = chosen
          .intersection({'playedBefore1', 'playedBefore2', 'playedBefore3'});
      expect(
        repeats.length,
        lessThan(3),
        reason: 'should not rerun the exact same four',
      );
    });

    test('with no history the fairness order is respected', () {
      final players = [
        player('first', waitingMinutes: 40),
        player('second', waitingMinutes: 30),
        player('third', waitingMinutes: 20),
        player('fourth', waitingMinutes: 10),
        player('fifth', waitingMinutes: 1),
      ];
      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(idsOf(suggestion), isNot(contains('fifth')));
    });
  });

  group('team balance', () {
    test('splits strongest + weakest against the middle two', () {
      final players = [
        player('adv', tier: SkillTier.advanced),
        player('int1', tier: SkillTier.intermediate),
        player('int2', tier: SkillTier.intermediate),
        player('beg', tier: SkillTier.beginner),
      ];

      final suggestion = service.suggestNext(players: players, now: _now)!;
      final teamAIds = suggestion.teamA.map((p) => p.id).toSet();

      expect(teamAIds, {'adv', 'beg'});
      expect(suggestion.teamB.map((p) => p.id).toSet(), {'int1', 'int2'});
    });

    test('always returns exactly two players per side', () {
      final players = List.generate(8, (i) => player('p$i'));
      final suggestion = service.suggestNext(players: players, now: _now)!;
      expect(suggestion.teamA.length, 2);
      expect(suggestion.teamB.length, 2);
      expect(idsOf(suggestion).length, 4, reason: 'no player appears twice');
    });
  });

  group('a simulated night stays fair', () {
    test('12 players over 12 rotations end within one game of each other', () {
      var players = List.generate(
        12,
        (i) => player('p$i', waitingMinutes: 12 - i),
      );
      final history = <GameMatch>[];
      var clock = _now;

      for (var round = 0; round < 12; round++) {
        final suggestion =
            service.suggestNext(players: players, now: clock, history: history)!;
        final playingIds = suggestion.allPlayers.map((p) => p.id).toSet();

        history.add(
          playedMatch(
            suggestion.teamA.map((p) => p.id).toList(),
            suggestion.teamB.map((p) => p.id).toList(),
          ),
        );

        clock = clock.add(const Duration(minutes: 12));

        // Tapos ang laro: dagdag ang bilang, reset ang paghihintay.
        players = players.map((p) {
          if (!playingIds.contains(p.id)) return p;
          return p.copyWith(gamesPlayed: p.gamesPlayed + 1, waitingSince: clock);
        }).toList();
      }

      final counts = players.map((p) => p.gamesPlayed).toList();
      final min = counts.reduce((a, b) => a < b ? a : b);
      final max = counts.reduce((a, b) => a > b ? a : b);

      expect(
        max - min,
        lessThanOrEqualTo(1),
        reason: 'games played: $counts',
      );
    });
  });
}
