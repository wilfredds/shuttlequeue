import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/fee_calculator.dart';

final _now = DateTime(2026, 7, 6, 23);

SessionPlayer player(
  String name, {
  int shuttles = 0,
  bool paid = false,
  PlayerStatus status = PlayerStatus.queued,
}) {
  return SessionPlayer(
    id: 'id-$name',
    name: name,
    skillTier: SkillTier.intermediate,
    gamesPlayed: 3,
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
}
