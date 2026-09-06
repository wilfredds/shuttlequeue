import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/club.dart';

Club club(String? number) => Club(
      id: 'c1',
      name: 'Test club',
      ownerUid: 'qm',
      gcashNumber: number,
    );

void main() {
  group('normalizeGcashNumber', () {
    test('accepts a plain 11-digit PH mobile number', () {
      expect(normalizeGcashNumber('09293656299'), '09293656299');
    });

    test('strips the spaces and dashes people actually type', () {
      expect(normalizeGcashNumber('0929 365 6299'), '09293656299');
      expect(normalizeGcashNumber('0929-365-6299'), '09293656299');
      expect(normalizeGcashNumber(' 0929 365 6299 '), '09293656299');
    });

    test('converts the +63 form to the local 09 form', () {
      expect(normalizeGcashNumber('+63 929 365 6299'), '09293656299');
      expect(normalizeGcashNumber('639293656299'), '09293656299');
    });

    test('rejects anything that is not a PH mobile number', () {
      expect(normalizeGcashNumber(''), isNull);
      expect(normalizeGcashNumber('12345'), isNull);
      // Landline, not mobile.
      expect(normalizeGcashNumber('0281234567'), isNull);
      // Too long.
      expect(normalizeGcashNumber('092936562999'), isNull);
      expect(normalizeGcashNumber('not a number'), isNull);
    });
  });

  group('display formatting', () {
    test('groups the digits so players can read them off a screen', () {
      expect(club('09293656299').formattedGcash, '0929 365 6299');
    });

    test('leaves an unexpected value alone rather than mangling it', () {
      expect(club('123').formattedGcash, '123');
    });

    test('hasGcash reflects whether it is set', () {
      expect(club('09293656299').hasGcash, isTrue);
      expect(club(null).hasGcash, isFalse);
      expect(club('').hasGcash, isFalse);
    });
  });
}
