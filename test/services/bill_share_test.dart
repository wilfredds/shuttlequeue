import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/services/bill_share.dart';
import 'package:shuttlequeue/services/fee_calculator.dart';

FeeLine line(
  String name, {
  required int court,
  int shuttle = 0,
  int games = 0,
  bool paid = false,
}) {
  return FeeLine(
    playerId: 'id-$name',
    name: name,
    courtShareCentavos: court,
    shuttleShareCentavos: shuttle,
    gamesPlayed: games,
    hasPaid: paid,
    hasLeft: false,
  );
}

FeeBreakdown breakdown(
  List<FeeLine> lines, {
  FeeMode mode = FeeMode.perHead,
  int courtFee = 0,
  int games = 0,
}) {
  return FeeBreakdown(
    lines: lines,
    mode: mode,
    expectedTotalCentavos:
        lines.fold(0, (sum, l) => sum + l.totalCentavos),
    courtFeeCentavos: courtFee,
    totalPlayerGames: games,
  );
}

String share(
  FeeBreakdown b, {
  String venue = 'Yspacio, Alapan, Imus',
  String? gcash,
  String Function(int)? gamesLabel,
  String? basisLine,
}) {
  return buildBillShareText(
    title: 'Monday Night Palo',
    dateLabel: 'Mon, Oct 20, 2026',
    venue: venue,
    breakdown: b,
    gcashTitle: 'GCash',
    gcashNumber: gcash,
    totalLabel: 'Total cost',
    collectedLabel: 'Collected',
    outstandingLabel: 'Outstanding',
    gamesLabel: gamesLabel,
    basisLine: basisLine,
  );
}

void main() {
  group('what the group chat actually receives', () {
    test('every player appears with their amount', () {
      final text = share(
        breakdown([
          line('Maricel', court: 16000, games: 8, paid: true),
          line('Jhun', court: 10000, games: 5),
        ]),
      );

      expect(text, contains('Monday Night Palo'));
      expect(text, contains('Mon, Oct 20, 2026'));
      expect(text, contains('Yspacio, Alapan, Imus'));
      expect(text, contains('✅ Maricel: ₱160.00'));
      expect(text, contains('— Jhun: ₱100.00'));
    });

    test('the totals are the last word', () {
      final text = share(
        breakdown([
          line('Maricel', court: 16000, paid: true),
          line('Jhun', court: 10000),
        ]),
      );

      expect(text, contains('Total cost: ₱260.00'));
      expect(text, contains('Collected: ₱160.00'));
      expect(text, contains('Outstanding: ₱100.00'));
    });

    test('the GCash number is included when the QM has set one', () {
      final text = share(
        breakdown([line('Maricel', court: 16000)]),
        gcash: '0929 365 6299',
      );
      expect(text, contains('GCash: 0929 365 6299'));
    });

    test('no GCash line at all when she has not set one', () {
      final text = share(breakdown([line('Maricel', court: 16000)]));
      expect(text, isNot(contains('GCash')));
    });

    test('a session with no venue does not leave a blank line', () {
      final text = share(breakdown([line('Ana', court: 100)]), venue: '   ');
      expect(text, isNot(contains('\n\n\n')));
    });
  });

  group('per-game: the amounts explain themselves', () {
    // ANG PROBLEMANG SINASAGOT NITO: sa per-game, iba-iba ang bayad. Ang
    // listahan ng magkakaibang halaga na walang dahilan ay mukhang mali sa
    // mata ng nagbabasa, at ang tanong ay dumarating sa QM nang paulit-ulit.
    FeeBreakdown perGame() => breakdown(
          [
            line('Maricel', court: 16000, games: 8),
            line('Jhun', court: 10000, games: 5),
            line('Bea', court: 6000, games: 3),
          ],
          mode: FeeMode.perGame,
          courtFee: 32000,
          games: 16,
        );

    test('each line carries the games it was charged for', () {
      final text = share(
        perGame(),
        gamesLabel: (g) => '$g games',
        basisLine: '₱20.00 per game · ₱320.00 court ÷ 16 games',
      );

      expect(text, contains('— Maricel (8 games): ₱160.00'));
      expect(text, contains('— Jhun (5 games): ₱100.00'));
      expect(text, contains('— Bea (3 games): ₱60.00'));
    });

    test('one line above the list explains the whole list', () {
      final text = share(
        perGame(),
        gamesLabel: (g) => '$g games',
        basisLine: '₱20.00 per game · ₱320.00 court ÷ 16 games',
      );

      expect(text, contains('₱20.00 per game'));
      // Nauuna ito sa mga pangalan, hindi nakabaon sa ilalim.
      expect(
        text.indexOf('per game'),
        lessThan(text.indexOf('Maricel')),
      );
    });

    test('per-head stays exactly as it was, with no game counts', () {
      final text = share(
        breakdown([
          line('Maricel', court: 16000, games: 8),
          line('Jhun', court: 16000, games: 5),
        ]),
      );

      expect(text, contains('— Maricel: ₱160.00'));
      expect(text, isNot(contains('games')));
    });
  });

  test('an empty bill still produces something sendable', () {
    final text = share(breakdown(const []));
    expect(text, contains('Monday Night Palo'));
    expect(text, contains('Total cost: ₱0.00'));
  });
}
