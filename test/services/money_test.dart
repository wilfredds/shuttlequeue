import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/services/money.dart';

void main() {
  group('parsePesosToCentavos', () {
    test('plain pesos', () {
      expect(parsePesosToCentavos('350'), 35000);
      expect(parsePesosToCentavos('0'), 0);
    });

    test('with centavos', () {
      expect(parsePesosToCentavos('350.50'), 35050);
      expect(parsePesosToCentavos('350.5'), 35050);
      expect(parsePesosToCentavos('0.99'), 99);
    });

    test('tolerates what a QM actually types', () {
      expect(parsePesosToCentavos('₱1,200'), 120000);
      expect(parsePesosToCentavos(' 350 '), 35000);
      expect(parsePesosToCentavos('P350.00'), 35000);
    });

    test('extra decimal digits are truncated, not rounded up', () {
      // Sinasadya: mas mabuting kulang ng 1 centavo kaysa sobra sa singil.
      expect(parsePesosToCentavos('10.567'), 1056);
    });

    test('returns null on junk instead of throwing', () {
      expect(parsePesosToCentavos(''), isNull);
      expect(parsePesosToCentavos('abc'), isNull);
      expect(parsePesosToCentavos('1.2.3'), isNull);
    });
  });

  group('formatCentavos', () {
    test('formats pesos and centavos', () {
      expect(formatCentavos(35000), '₱350.00');
      expect(formatCentavos(35050), '₱350.50');
      expect(formatCentavos(99), '₱0.99');
      expect(formatCentavos(0), '₱0.00');
    });

    test('groups thousands', () {
      expect(formatCentavos(120000), '₱1,200.00');
      expect(formatCentavos(123456789), '₱1,234,567.89');
    });

    test('handles negative balances (sobrang bayad)', () {
      expect(formatCentavos(-5000), '-₱50.00');
    });
  });
}
