import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/services/session_schedule.dart';

void main() {
  // 2026-09-07 ay Lunes.
  final monday = DateTime(2026, 9, 7, 20);
  final thursday = DateTime(2026, 9, 10, 20);

  group('nextOccurrence', () {
    test('a weekly session lands on the same weekday next week', () {
      // Ginawa noong Lunes; ngayon ay Martes → susunod na Lunes.
      final now = DateTime(2026, 9, 8, 14);
      final next = nextOccurrence(monday, now);

      expect(next, DateTime(2026, 9, 14, 20));
      expect(next.weekday, DateTime.monday);
    });

    test('same weekday means today, not next week', () {
      // Inaayos ng QM ang gabi mismong Lunes ng hapon.
      final now = DateTime(2026, 9, 14, 15);
      expect(nextOccurrence(monday, now), DateTime(2026, 9, 14, 20));
    });

    test('still today even if the usual start time has already passed', () {
      // 8:30pm na, alas-8 ang nakasanayang simula. Kadalasan ay huli lang
      // siyang nag-set up — hindi ibig sabihin nito na sa susunod na linggo.
      final now = DateTime(2026, 9, 14, 20, 30);
      expect(nextOccurrence(monday, now), DateTime(2026, 9, 14, 20));
    });

    test('keeps the original time of day, not the current time', () {
      final now = DateTime(2026, 9, 9, 6, 45);
      final next = nextOccurrence(thursday, now);

      expect(next.hour, 20);
      expect(next.minute, 0);
    });

    test('handles a session whose weekday is tomorrow', () {
      // Miyerkules ngayon; Huwebes ang session → bukas.
      final now = DateTime(2026, 9, 9, 10);
      expect(nextOccurrence(thursday, now), DateTime(2026, 9, 10, 20));
    });

    test('wraps across a month boundary', () {
      // Lunes 28 Set; ang susunod na Huwebes ay 1 Okt.
      final now = DateTime(2026, 9, 28, 9);
      expect(nextOccurrence(thursday, now), DateTime(2026, 10, 1, 20));
    });

    test('wraps across a year boundary', () {
      // Miyerkules 30 Dis 2026; ang susunod na Huwebes ay 31 Dis.
      final now = DateTime(2026, 12, 30, 9);
      expect(nextOccurrence(thursday, now), DateTime(2026, 12, 31, 20));

      // Huwebes 31 Dis; ang susunod na Lunes ay 4 Ene 2027.
      final newYearsEve = DateTime(2026, 12, 31, 9);
      expect(nextOccurrence(monday, newYearsEve), DateTime(2027, 1, 4, 20));
    });

    test('preserves minutes, not just the hour', () {
      final halfPast = DateTime(2026, 9, 10, 19, 30);
      final now = DateTime(2026, 9, 9, 8);
      expect(nextOccurrence(halfPast, now), DateTime(2026, 9, 10, 19, 30));
    });

    test('an old session from months ago still suggests the next one', () {
      final ancient = DateTime(2026, 3, 2, 20); // a Monday
      final now = DateTime(2026, 9, 9, 12); // a Wednesday
      final next = nextOccurrence(ancient, now);

      expect(next.weekday, DateTime.monday);
      expect(next.isAfter(now), isTrue);
      expect(next, DateTime(2026, 9, 14, 20));
    });
  });
}
