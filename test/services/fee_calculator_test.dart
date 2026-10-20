import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/fee_calculator.dart';

final _now = DateTime(2026, 7, 6, 23);

SessionPlayer player(
  String name, {
  int shuttles = 0,
  bool paid = false,
  int games = 3,
  int gamesAtJoin = 0,
  PlayerStatus status = PlayerStatus.queued,
}) {
  return SessionPlayer(
    id: 'id-$name',
    name: name,
    skillTier: SkillTier.intermediate,
    gamesPlayed: games,
    gamesAtJoin: gamesAtJoin,
    waitingSince: _now,
    status: status,
    shuttlesUsed: shuttles,
    hasPaid: paid,
    createdAt: _now,
  );
}

void main() {
  const calc = FeeCalculator();

  group('per-head mode', () {
    test('splits the court fee evenly and charges own shuttles', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', shuttles: 2),
          player('Ben', shuttles: 0),
          player('Carl', shuttles: 1),
          player('Dina', shuttles: 1),
        ],
        courtFeeCentavos: 120000, // ₱1200
        shuttlePriceCentavos: 10000, // ₱100
        feeMode: FeeMode.perHead,
      );

      // ₱1200 ÷ 4 = ₱300 bawat isa
      expect(breakdown.lines.every((l) => l.courtShareCentavos == 30000), isTrue);

      final ana = breakdown.lines.firstWhere((l) => l.name == 'Ana');
      expect(ana.shuttleShareCentavos, 20000);
      expect(ana.totalCentavos, 50000); // ₱500

      final ben = breakdown.lines.firstWhere((l) => l.name == 'Ben');
      expect(ben.totalCentavos, 30000); // walang shuttle, court share lang

      // ₱1200 court + 4 shuttles × ₱100 = ₱1600
      expect(breakdown.expectedTotalCentavos, 160000);
      expect(breakdown.balances, isTrue);
    });
  });

  group('american mode', () {
    test('pools everything and splits it equally', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', shuttles: 4), // gumamit ng marami...
          player('Ben'),
          player('Carl'),
          player('Dina'),
        ],
        courtFeeCentavos: 120000,
        shuttlePriceCentavos: 10000,
        feeMode: FeeMode.american,
      );

      // (₱1200 + 4 × ₱100) ÷ 4 = ₱400 bawat isa
      expect(breakdown.lines.every((l) => l.totalCentavos == 40000), isTrue);
      // ...pero pantay pa rin ang hati — iyon ang punto ng american.
      expect(breakdown.balances, isTrue);
    });
  });

  group('remainder distribution — the money-losing bug class', () {
    test('₱1000 across 7 players sums back to exactly ₱1000', () {
      final players = List.generate(7, (i) => player('P$i'));
      final breakdown = calc.calculate(
        players: players,
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
      );

      expect(breakdown.chargedTotalCentavos, 100000);
      expect(breakdown.balances, isTrue);

      // 100000 ÷ 7 = 14285 tira 5 → lima ang nagbabayad ng dagdag na centavo.
      final extras =
          breakdown.lines.where((l) => l.courtShareCentavos == 14286).length;
      expect(extras, 5);
      expect(
        breakdown.lines.where((l) => l.courtShareCentavos == 14285).length,
        2,
      );
    });

    test('every awkward divisor still balances exactly', () {
      for (var count = 1; count <= 40; count++) {
        for (final fee in [100000, 123456, 99999, 1, 0]) {
          final breakdown = calc.calculate(
            players: List.generate(count, (i) => player('P$i')),
            courtFeeCentavos: fee,
            shuttlePriceCentavos: 0,
            feeMode: FeeMode.perHead,
          );
          expect(
            breakdown.chargedTotalCentavos,
            fee,
            reason: 'fee $fee across $count players did not balance',
          );
        }
      }
    });

    test('american mode balances across awkward divisors too', () {
      for (var count = 1; count <= 20; count++) {
        final breakdown = calc.calculate(
          players: List.generate(count, (i) => player('P$i', shuttles: i % 3)),
          courtFeeCentavos: 123457,
          shuttlePriceCentavos: 8333,
          feeMode: FeeMode.american,
        );
        expect(breakdown.balances, isTrue, reason: '$count players');
      }
    });

    test('the same player always gets the same share (stable ordering)', () {
      final players = [player('Zoe'), player('Ana'), player('Mia')];
      final first = calc.calculate(
        players: players,
        courtFeeCentavos: 100,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
      );
      final second = calc.calculate(
        players: players.reversed.toList(),
        courtFeeCentavos: 100,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
      );

      for (final line in first.lines) {
        final other = second.lines.firstWhere((l) => l.name == line.name);
        expect(other.totalCentavos, line.totalCentavos);
      }
    });
  });

  group('edge cases that would crash or overcharge', () {
    test('nobody attending returns an empty breakdown, not a crash', () {
      final breakdown = calc.calculate(
        players: const [],
        courtFeeCentavos: 120000,
        shuttlePriceCentavos: 10000,
        feeMode: FeeMode.perHead,
      );
      expect(breakdown.lines, isEmpty);
      expect(breakdown.chargedTotalCentavos, 0);
    });

    test('players who left early still pay their share', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana'),
          player('WentHome', status: PlayerStatus.left),
        ],
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
      );

      expect(breakdown.lines.length, 2);
      final left = breakdown.lines.firstWhere((l) => l.name == 'WentHome');
      expect(left.totalCentavos, 50000);
      expect(left.hasLeft, isTrue);
    });

    test('leavers can be excluded when the QM prefers that', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana'),
          player('WentHome', status: PlayerStatus.left),
        ],
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
        includeLeavers: false,
      );
      expect(breakdown.lines.length, 1);
      expect(breakdown.lines.single.totalCentavos, 100000);
    });

    test('a free session charges nothing', () {
      final breakdown = calc.calculate(
        players: [player('Ana'), player('Ben')],
        courtFeeCentavos: 0,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
      );
      expect(breakdown.chargedTotalCentavos, 0);
      expect(breakdown.balances, isTrue);
    });
  });

  group('collection tracking', () {
    test('tracks what has been collected and what is still owed', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', paid: true),
          player('Ben'),
          player('Carl', paid: true),
          player('Dina'),
        ],
        courtFeeCentavos: 120000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perHead,
      );

      expect(breakdown.paidCount, 2);
      expect(breakdown.collectedCentavos, 60000);
      expect(breakdown.outstandingCentavos, 60000);
    });
  });

  // -------------------------------------------------------------------------
  // per-game mode - ang kabayaran ay lumalaki habang dumadami ang laro
  // -------------------------------------------------------------------------
  //
  // Ito ang hinihingi ng totoong QM: ang naglaro ng walong laro ay dapat mas
  // malaki ang bayad kaysa sa naglaro ng tatlo. Pero ang renta ng court ay
  // nananatiling iisang halaga - kaya ang hatian ay ayon sa bilang ng laro,
  // hindi isang bagong presyo kada laro. Ang kabuuan ay dapat pa rin mapunta
  // nang eksakto sa renta.
  group('per-game mode', () {
    test('a player who played more games pays more', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 8),
          player('Ben', games: 4),
          player('Carl', games: 2),
          player('Dina', games: 1),
        ],
        courtFeeCentavos: 150000, // ₱1500
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      int courtOf(String name) =>
          breakdown.lines.firstWhere((l) => l.name == name).courtShareCentavos;

      // 15 player-game sa kabuuan, ₱1500 / 15 = ₱100 kada laro.
      expect(courtOf('Ana'), 80000);
      expect(courtOf('Ben'), 40000);
      expect(courtOf('Carl'), 20000);
      expect(courtOf('Dina'), 10000);

      // ANG INVARIANT: eksaktong renta ang nakolekta.
      expect(breakdown.chargedTotalCentavos, 150000);
      expect(breakdown.balances, isTrue);
    });

    test('the rate per game is reported so the QM can explain it', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 8),
          player('Ben', games: 4),
          player('Carl', games: 2),
          player('Dina', games: 1),
        ],
        courtFeeCentavos: 150000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      expect(breakdown.totalPlayerGames, 15);
      expect(breakdown.courtRatePerGameCentavos, 10000); // ₱100
    });

    test('each line carries the game count it was charged for', () {
      final breakdown = calc.calculate(
        players: [player('Ana', games: 8), player('Ben', games: 4)],
        courtFeeCentavos: 120000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      expect(breakdown.lines.firstWhere((l) => l.name == 'Ana').gamesPlayed, 8);
    });

    test('someone who never got on court owes nothing for the court', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 5),
          player('Ben', games: 5),
          // Dumating, humawak ng shuttle, pero hindi nakalaro.
          player('Zeny', games: 0, shuttles: 1),
        ],
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 8000,
        feeMode: FeeMode.perGame,
      );

      final zeny = breakdown.lines.firstWhere((l) => l.name == 'Zeny');
      expect(zeny.courtShareCentavos, 0);
      // Ang shuttle ay sa kanya pa rin - hinawakan niya iyon.
      expect(zeny.shuttleShareCentavos, 8000);

      expect(breakdown.chargedTotalCentavos, 108000);
      expect(breakdown.balances, isTrue);
    });

    test('shuttles stay personal, exactly as in per-head', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 2, shuttles: 3),
          player('Ben', games: 2, shuttles: 0),
        ],
        courtFeeCentavos: 40000,
        shuttlePriceCentavos: 9000,
        feeMode: FeeMode.perGame,
      );

      final ana = breakdown.lines.firstWhere((l) => l.name == 'Ana');
      final ben = breakdown.lines.firstWhere((l) => l.name == 'Ben');
      expect(ana.shuttleShareCentavos, 27000);
      expect(ben.shuttleShareCentavos, 0);
      // Pantay ang laro, kaya pantay ang court share.
      expect(ana.courtShareCentavos, ben.courtShareCentavos);
      expect(breakdown.balances, isTrue);
    });

    test('an awkward divisor still sums back to exactly the court fee', () {
      // ₱1000 sa 7 player-game: 100000 / 7 = 14285 na may tirang 5.
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 3),
          player('Ben', games: 2),
          player('Carl', games: 1),
          player('Dina', games: 1),
        ],
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      expect(breakdown.chargedTotalCentavos, 100000);
      expect(breakdown.balances, isTrue);
    });

    test('the centavo remainder never lands on a player with no games', () {
      for (var fee = 1; fee <= 400; fee++) {
        final breakdown = calc.calculate(
          players: [
            player('Ana', games: 1),
            player('Ben', games: 1),
            player('Carl', games: 1),
            player('Zeny', games: 0),
            player('Yoly', games: 0),
          ],
          courtFeeCentavos: fee,
          shuttlePriceCentavos: 0,
          feeMode: FeeMode.perGame,
        );

        for (final name in ['Zeny', 'Yoly']) {
          expect(
            breakdown.lines
                .firstWhere((l) => l.name == name)
                .courtShareCentavos,
            0,
            reason: 'fee=$fee: hindi nakalaro si $name, dapat walang share',
          );
        }
        expect(breakdown.chargedTotalCentavos, fee, reason: 'fee=$fee');
      }
    });

    test('every fee and game spread still balances exactly', () {
      for (var fee = 0; fee < 2000; fee += 7) {
        for (var spread = 1; spread <= 9; spread++) {
          final breakdown = calc.calculate(
            players: [
              for (var i = 0; i < 9; i++)
                player('P$i', games: (i * spread) % 11),
            ],
            courtFeeCentavos: fee * 100,
            shuttlePriceCentavos: 0,
            feeMode: FeeMode.perGame,
          );
          expect(breakdown.balances, isTrue, reason: 'fee=$fee spread=$spread');
        }
      }
    });

    test('the same player always gets the same share', () {
      List<int> run() {
        final breakdown = calc.calculate(
          players: [
            player('Dina', games: 4),
            player('Ana', games: 3),
            player('Carl', games: 3),
            player('Ben', games: 1),
          ],
          courtFeeCentavos: 100000,
          shuttlePriceCentavos: 0,
          feeMode: FeeMode.perGame,
        );
        final sorted = [...breakdown.lines]
          ..sort((a, b) => a.name.compareTo(b.name));
        return sorted.map((l) => l.courtShareCentavos).toList();
      }

      expect(run(), run());
    });

    test('before the first game, the court is split evenly', () {
      // Walang nalalaro pa pero may renta na ang court. Kung hahatiin natin
      // ayon sa laro, zero ang lahat at ang QM ang aabono ng buong renta.
      final breakdown = calc.calculate(
        players: [player('Ana', games: 0), player('Ben', games: 0)],
        courtFeeCentavos: 100000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      expect(
        breakdown.lines.every((l) => l.courtShareCentavos == 50000),
        isTrue,
      );
      expect(breakdown.chargedTotalCentavos, 100000);
      expect(breakdown.balances, isTrue);
    });

    test('a player who left early still pays for the games they played', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 2),
          player('Ben', games: 2),
          player('Early', games: 4, status: PlayerStatus.left),
        ],
        courtFeeCentavos: 80000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      final early = breakdown.lines.firstWhere((l) => l.name == 'Early');
      expect(early.hasLeft, isTrue);
      // 8 player-game, ₱800 -> ₱100 kada laro, apat na laro = ₱400.
      expect(early.courtShareCentavos, 40000);
      expect(breakdown.balances, isTrue);
    });

    test('a late arrival only pays for the games they actually played', () {
      // ANG BITAG: ang dumating nang alas-nuwebe ay BINIBIGYAN ng
      // gamesPlayed na katumbas ng pinakamababa sa pila (tingnan ang
      // addLateArrival) para hindi siya unahin ng algorithm sa lahat.
      // Tama iyon para sa pila. Pero ang bilang na iyon ay hindi laro na
      // nilaro niya — at kapag pera na ang nakasalalay dito, binabayaran
      // niya ang mga larong hindi niya nalaro, at ang iba ay kulang ang
      // bayad dahil nakataling-isa ang kabuuan.
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 6),
          player('Ben', games: 6),
          // Dumating nang huli: binuhat sa 3, tapos tatlong laro lang.
          player('Late', games: 6, gamesAtJoin: 3),
        ],
        courtFeeCentavos: 150000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      int courtOf(String name) =>
          breakdown.lines.firstWhere((l) => l.name == name).courtShareCentavos;

      // 6 + 6 + 3 = 15 tunay na player-game, ₱1500 / 15 = ₱100.
      expect(courtOf('Ana'), 60000);
      expect(courtOf('Ben'), 60000);
      expect(courtOf('Late'), 30000);
      expect(breakdown.totalPlayerGames, 15);
      expect(breakdown.chargedTotalCentavos, 150000);
      expect(breakdown.balances, isTrue);
    });

    test('the line shows the games played, not the seeded head start', () {
      final breakdown = calc.calculate(
        players: [player('Late', games: 9, gamesAtJoin: 4)],
        courtFeeCentavos: 50000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );
      expect(breakdown.lines.single.gamesPlayed, 5);
    });

    test('a late arrival who never played owes nothing for the court', () {
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 4),
          // Binuhat sa 4, hindi pa nakakalaro.
          player('Late', games: 4, gamesAtJoin: 4),
        ],
        courtFeeCentavos: 40000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );
      expect(
        breakdown.lines.firstWhere((l) => l.name == 'Late').courtShareCentavos,
        0,
      );
      expect(breakdown.chargedTotalCentavos, 40000);
    });

    test('a corrupt head start never bills a negative amount', () {
      // Kung may sumirang undo at mas mataas ang gamesAtJoin kaysa sa
      // gamesPlayed, hindi dapat ito maging negatibong singil.
      final breakdown = calc.calculate(
        players: [
          player('Ana', games: 5),
          player('Odd', games: 2, gamesAtJoin: 9),
        ],
        courtFeeCentavos: 50000,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );
      final odd = breakdown.lines.firstWhere((l) => l.name == 'Odd');
      expect(odd.courtShareCentavos, 0);
      expect(odd.gamesPlayed, 0);
      expect(breakdown.balances, isTrue);
    });

    test('a free court charges nothing even with games played', () {
      final breakdown = calc.calculate(
        players: [player('Ana', games: 5), player('Ben', games: 3)],
        courtFeeCentavos: 0,
        shuttlePriceCentavos: 0,
        feeMode: FeeMode.perGame,
      );

      expect(breakdown.chargedTotalCentavos, 0);
      expect(breakdown.courtRatePerGameCentavos, 0);
      expect(breakdown.balances, isTrue);
    });
  });
}
