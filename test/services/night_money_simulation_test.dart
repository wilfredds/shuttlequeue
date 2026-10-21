/// Isang buong gabi, pinatakbo nang paulit-ulit, at ang tanong ay iisa:
/// **tumutugma ba ang nakolekta sa tunay na gastos?**
///
/// Hindi ito unit test ng isang function. Pinagsasama nito ang dalawang
/// serbisyong magkaibang-magkaiba ang trabaho — kung sino ang naglalaro
/// (MatchmakingService) at kung sino ang nagbabayad (FeeCalculator) — dahil
/// doon nagtatago ang pinakamahal na uri ng bug: tama ang bawat isa nang
/// mag-isa, mali sila nang magkasama.
///
/// Ganoon eksakto ang nangyari sa `gamesAtJoin`. Tama ang pagbuhat sa
/// dumating nang huli para sa pila, at tama ang hatian ayon sa laro para sa
/// pera. Magkasama, sinisingil nila ang isang tao para sa tatlong larong
/// wala pa siya. Walang unit test ang makakahuli niyon.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/fee_calculator.dart';
import 'package:shuttlequeue/services/matchmaking_service.dart';

final _start = DateTime(2026, 10, 21, 20);

SessionPlayer _p(
  String name, {
  SkillTier tier = SkillTier.intermediate,
  int gamesAtJoin = 0,
  DateTime? joinedAt,
}) {
  return SessionPlayer(
    id: 'id-$name',
    name: name,
    skillTier: tier,
    gamesPlayed: gamesAtJoin,
    gamesAtJoin: gamesAtJoin,
    waitingSince: joinedAt ?? _start,
    status: PlayerStatus.queued,
    shuttlesUsed: 0,
    hasPaid: false,
    createdAt: joinedAt ?? _start,
  );
}

/// Pinapatakbo ang gabi: [rounds] na laro sa [courts] na court.
///
/// Ginagaya nito ang totoong daloy ng app — `suggestNext` para pumili,
/// tapos `endMatch` na nagdadagdag ng isa sa bawat isa sa apat.
({List<SessionPlayer> players, List<GameMatch> history}) _runNight({
  required List<SessionPlayer> players,
  required int rounds,
  int courts = 2,
  void Function(int round, List<SessionPlayer> players)? onRound,
}) {
  const service = MatchmakingService();
  var roster = [...players];
  final history = <GameMatch>[];
  var clock = _start;

  for (var round = 0; round < rounds; round++) {
    for (var court = 0; court < courts; court++) {
      final suggestion = service.suggestNext(
        players: roster,
        now: clock,
        history: history,
      );
      if (suggestion == null) continue;

      final four = suggestion.allPlayers.map((p) => p.id).toSet();
      history.add(
        GameMatch(
          id: 'm${history.length}',
          courtId: 'court-$court',
          teamA: suggestion.teamA.map((p) => p.id).toList(),
          teamB: suggestion.teamB.map((p) => p.id).toList(),
          startedAt: clock,
          endedAt: clock.add(const Duration(minutes: 14)),
        ),
      );

      // endMatch: +1 sa bawat isa sa apat, at muling nagsisimula ang hintay.
      roster = [
        for (final p in roster)
          if (four.contains(p.id))
            p.copyWith(
              gamesPlayed: p.gamesPlayed + 1,
              waitingSince: clock,
              status: PlayerStatus.queued,
            )
          else
            p,
      ];
    }

    clock = clock.add(const Duration(minutes: 14));
    onRound?.call(round, roster);
  }

  return (players: roster, history: history);
}

void main() {
  const calc = FeeCalculator();

  group('a whole night, end to end', () {
    test('the collected total lands exactly on the night\'s cost', () {
      final night = _runNight(
        players: [
          _p('Maricel'),
          _p('Jhun', tier: SkillTier.advanced),
          _p('Bea', tier: SkillTier.beginner),
          _p('Rico'),
          _p('Neneng', tier: SkillTier.beginner),
          _p('Dondon', tier: SkillTier.advanced),
          _p('Aileen'),
          _p('Jomar'),
          _p('Shiela', tier: SkillTier.beginner),
          _p('Tope', tier: SkillTier.advanced),
          _p('Evelyn'),
          _p('Paeng'),
        ],
        rounds: 9,
      );

      // May kumuha ng bola sa kalagitnaan ng gabi.
      final roster = [
        for (final (i, p) in night.players.indexed)
          if (i % 4 == 0) p.copyWith(shuttlesUsed: 2) else p,
      ];

      const courtFee = 180000; // ₱1,800 para sa dalawang court
      const shuttlePrice = 9000; // ₱90 kada bola

      for (final mode in FeeMode.values) {
        final bill = calc.calculate(
          players: roster,
          courtFeeCentavos: courtFee,
          shuttlePriceCentavos: shuttlePrice,
          feeMode: mode,
        );

        final shuttles = roster.fold(0, (sum, p) => sum + p.shuttlesUsed);
        expect(
          bill.expectedTotalCentavos,
          courtFee + shuttles * shuttlePrice,
          reason: '$mode',
        );
        expect(
          bill.chargedTotalCentavos,
          bill.expectedTotalCentavos,
          reason: 'ang QM ang mag-aabono ng diperensya sa $mode',
        );
        expect(bill.balances, isTrue, reason: '$mode');
        expect(bill.lines.length, roster.length, reason: '$mode');

        // Walang sinisingil ng negatibo. Ang bill na may negatibong linya
        // ay nagbibigay ng pera sa isang tao sa dulo ng gabi.
        for (final line in bill.lines) {
          expect(line.courtShareCentavos, greaterThanOrEqualTo(0));
          expect(line.shuttleShareCentavos, greaterThanOrEqualTo(0));
        }
      }
    });

    test('the rotation stays fair, which is what per-game bills rest on', () {
      final night = _runNight(
        players: [
          for (var i = 0; i < 12; i++) _p('P$i'),
        ],
        rounds: 9,
      );

      final counts = night.players.map((p) => p.billableGames).toList()..sort();
      // Kung hindi patas ang pila, hindi patas ang bill — iisang bilang
      // ang pinagbabatayan ng dalawa.
      expect(counts.last - counts.first, lessThanOrEqualTo(1));
    });

    test('a late arrival pays only from the moment they walked in', () {
      // Anim na round muna, tapos dumating si Late.
      final first = _runNight(
        players: [for (var i = 0; i < 8; i++) _p('P$i')],
        rounds: 6,
      );

      // addLateArrival: binubuhat sa pinakamababa sa mga aktibo.
      final baseline = first.players
          .map((p) => p.gamesPlayed)
          .reduce((a, b) => a < b ? a : b);
      expect(baseline, greaterThan(0), reason: 'kung hindi, walang sinusubok');

      final second = _runNight(
        players: [
          ...first.players,
          _p('Late', gamesAtJoin: baseline, joinedAt: _start),
        ],
        rounds: 4,
      );

      final late = second.players.firstWhere((p) => p.name == 'Late');
      expect(late.gamesPlayed, greaterThan(baseline));
      expect(late.billableGames, late.gamesPlayed - baseline);

      const courtFee = 120000;
      final bill = calc.calculate(
        players: second.players,
        courtFeeCentavos: courtFee,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      final lateLine = bill.lines.firstWhere((l) => l.name == 'Late');
      final anyOther = bill.lines.firstWhere((l) => l.name != 'Late');

      // Mas kaunti ang laro niya, kaya mas maliit ang bayad niya.
      expect(lateLine.gamesPlayed, lessThan(anyOther.gamesPlayed));
      expect(
        lateLine.courtShareCentavos,
        lessThan(anyOther.courtShareCentavos),
      );
      expect(bill.balances, isTrue);
    });

    test('someone who left early still pays for what they played', () {
      final night = _runNight(
        players: [for (var i = 0; i < 8; i++) _p('P$i')],
        rounds: 6,
      );

      final roster = [
        for (final (i, p) in night.players.indexed)
          if (i == 0) p.copyWith(status: PlayerStatus.left) else p,
      ];

      final bill = calc.calculate(
        players: roster,
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      final leaver = bill.lines.firstWhere((l) => l.hasLeft);
      expect(leaver.courtShareCentavos, greaterThan(0));
      expect(bill.balances, isTrue);
    });

    test('a night that never got going does not charge nonsense', () {
      // Dumating ang lahat, walang nalaro — umulan, nasira ang ilaw.
      final roster = [for (var i = 0; i < 6; i++) _p('P$i')];

      for (final mode in FeeMode.values) {
        final bill = calc.calculate(
          players: roster,
          courtFeeCentavos: 90000,
          shuttlePriceCentavos: 0,
          feeMode: mode,
        );
        // Bayad pa rin ang court, kaya hinahati pa rin ito.
        expect(bill.chargedTotalCentavos, 90000, reason: '$mode');
        expect(bill.balances, isTrue, reason: '$mode');
      }
    });
  });

  group('the invariant holds across many nights, not just one', () {
    test('every court fee and roster size still balances exactly', () {
      for (var size = 4; size <= 20; size += 2) {
        for (var fee = 0; fee <= 250000; fee += 37100) {
          final night = _runNight(
            players: [for (var i = 0; i < size; i++) _p('P$i')],
            rounds: 7,
          );

          final roster = [
            for (final (i, p) in night.players.indexed)
              p.copyWith(shuttlesUsed: i % 3),
          ];

          for (final mode in FeeMode.values) {
            final bill = calc.calculate(
              players: roster,
              courtFeeCentavos: fee,
              shuttlePriceCentavos: 8500,
              feeMode: mode,
            );
            expect(
              bill.balances,
              isTrue,
              reason: 'size=$size fee=$fee mode=$mode',
            );
          }
        }
      }
    });
  });
}
