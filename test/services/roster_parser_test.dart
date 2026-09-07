import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/services/roster_parser.dart';

void main() {
  List<String> namesOf(ParsedRoster roster) =>
      roster.entries.map((e) => e.name).toList();

  group('numbering formats', () {
    test('strips every numbering style a group chat produces', () {
      const raw = '''
1. Jun
2) Ana
3 - Mark
#4 Paolo
05. Rica
6 Kim
''';
      expect(
        namesOf(parseRoster(raw)),
        ['Jun', 'Ana', 'Mark', 'Paolo', 'Rica', 'Kim'],
      );
    });

    test('handles an unnumbered list too', () {
      const raw = 'Jun\nAna\nMark';
      expect(namesOf(parseRoster(raw)), ['Jun', 'Ana', 'Mark']);
    });
  });

  group('real Messenger noise', () {
    test('drops the session header but keeps it visible to the QM', () {
      const raw = '''
MONDAY NIGHT PALO — JULY 06, 2026 | 8pm to 12mn
1. Jun
2. Ana
''';
      final roster = parseRoster(raw);
      expect(namesOf(roster), ['Jun', 'Ana']);
      // Hindi tahimik ang pagtapon — nakikita ng QM (R-08).
      expect(roster.skippedLines, contains(contains('MONDAY NIGHT PALO')));
    });

    test('strips emoji but keeps accented letters', () {
      const raw = '1. Jun 🔥\n2. Niña ✅\n3. José';
      expect(namesOf(parseRoster(raw)), ['Jun', 'Niña', 'José']);
    });

    test('pulls parenthetical notes off the name', () {
      const raw = '1. Ana (late 9pm)\n2. Mark (maybe)';
      final roster = parseRoster(raw);
      expect(namesOf(roster), ['Ana', 'Mark']);
      expect(roster.entries[0].note, 'late 9pm');
      expect(roster.entries[1].note, 'maybe');
    });

    test('chatter between numbered lines is skipped, not turned into players',
        () {
      const raw = '''
1. Jun
sana all
2. Ana
sino pa?
''';
      final roster = parseRoster(raw);
      expect(namesOf(roster), ['Jun', 'Ana']);
      expect(roster.skippedLines, containsAll(['sana all', 'sino pa?']));
    });

    test('trailing markers are trimmed', () {
      const raw = '1. Jun -\n2. Ana,';
      expect(namesOf(parseRoster(raw)), ['Jun', 'Ana']);
    });

    test('blank lines and separators never become players', () {
      const raw = '1. Jun\n\n---\n2. Ana\n';
      expect(namesOf(parseRoster(raw)), ['Jun', 'Ana']);
    });
  });

  group('guests (+1)', () {
    test('creates a separate row so the guest gets their own games and bill',
        () {
      const raw = '1. Jun +1\n2. Ana';
      final roster = parseRoster(raw);
      expect(namesOf(roster), ['Jun', 'Jun +1', 'Ana']);
      expect(roster.entries[1].isGuest, isTrue);
    });

    test('handles +2 and the word "plus"', () {
      expect(namesOf(parseRoster('1. Jun +2')), ['Jun', 'Jun +1', 'Jun +2']);
      expect(namesOf(parseRoster('1. Ana plus 1')), ['Ana', 'Ana +1']);
    });

    test('absurd guest counts are capped rather than trusted', () {
      // "+40" ay typo, hindi 40 bisita.
      expect(parseRoster('1. Jun +40').entries.length, lessThanOrEqualTo(6));
    });
  });

  group('duplicates — R-07, the dangerous one', () {
    test('two players named Jun are BOTH kept, and flagged', () {
      const raw = '1. Jun\n2. Ana\n3. Jun';
      final roster = parseRoster(raw);

      // Hindi kailanman pinagsasama: dalawang tao talaga sila.
      expect(namesOf(roster), ['Jun', 'Ana', 'Jun']);
      expect(roster.entries[2].isDuplicate, isTrue);
      expect(roster.entries[0].isDuplicate, isFalse);
      expect(roster.duplicateCount, 1);
    });

    test('duplicate detection ignores case', () {
      final roster = parseRoster('1. jun\n2. JUN');
      expect(roster.entries.length, 2);
      expect(roster.entries[1].isDuplicate, isTrue);
    });
  });

  group('never crashes', () {
    test('empty and whitespace input', () {
      expect(parseRoster('').isEmpty, isTrue);
      expect(parseRoster('   \n\n  ').isEmpty, isTrue);
    });

    test('numbers-only lines are not players', () {
      expect(parseRoster('1. 123\n2. Jun').entries.length, 1);
    });
  });

  group('a full realistic paste', () {
    test('produces a clean roster from a messy list', () {
      const raw = '''
MONDAY NIGHT PALO — JULY 06, 2026 | 8pm to 12mn
Yspacio, Alapan, Imus
Court fee 1200

1. Jun P.
2. Ana 🏸
3. Mark (late 9pm)
4. Rica +1
5. Kim
6. jun

sana all
''';
      final roster = parseRoster(raw);

      expect(
        namesOf(roster),
        ['Jun P.', 'Ana', 'Mark', 'Rica', 'Rica +1', 'Kim', 'jun'],
      );
      expect(roster.entries[4].isGuest, isTrue);
      // "jun" ay iba sa "Jun P." — walang dapat i-flag.
      expect(roster.duplicateCount, 0);
      expect(roster.skippedLines, isNotEmpty);
    });
  });

  group('mga markang "confirmed/bayad na" — R-08', () {
    // Ang tunay na group chat ay puno ng ganito. Nadiskubre ko lang ito
    // nang subukan kong hulaan ang hitsura ng listahan ng club ni France:
    // NAWAWALA ang mga taong ito bago pa man magsimula ang gabi.
    test('ang estado sa dulo ay hindi bumubura ng manlalaro', () {
      final roster = parseRoster([
        'Jun - paid',
        'Ana paid',
        'Rica — bayad',
        'Niña ok',
        'Paolo confirmed',
      ].join('\n'));

      expect(
        roster.entries.map((e) => e.name).toList(),
        ['Jun', 'Ana', 'Rica', 'Niña', 'Paolo'],
      );
      expect(roster.skippedLines, isEmpty);
    });

    test('ang mahabang note ay hindi ginagawang header ang linya', () {
      // 41 titik ito, at ang lumang panuntunang "mahaba = pangungusap"
      // ay sinusukat ang HILAW na linya — kaya nabubura si Mark.
      final roster = parseRoster('Mark Anthony (late, might come after work)');

      expect(roster.entries.single.name, 'Mark Anthony');
      expect(roster.entries.single.note, 'late, might come after work');
    });

    test('hindi rin nawawala ang bisita sa likod ng mahabang note', () {
      final roster =
          parseRoster('Kuya Jun (bringing a friend later tonight) +1');

      expect(
        roster.entries.map((e) => e.name).toList(),
        ['Kuya Jun', 'Kuya Jun +1'],
      );
    });
  });

  group('mga apelyidong Pilipino na halos mabura', () {
    // Ang listahan ng estado ay may word boundary. Kung wala iyon,
    // ang "ok" sa dulo ng Diok at Jomok ay puputol sa pangalan — at
    // ang "Go" ay tunay na apelyido rito.
    test('hindi kinakain ang dulo ng tunay na pangalan', () {
      final roster = parseRoster(
        ['Mark Go', 'Diok', 'Jomok', 'Kevin', 'Ana Uy'].join('\n'),
      );

      expect(
        roster.entries.map((e) => e.name).toList(),
        ['Mark Go', 'Diok', 'Jomok', 'Kevin', 'Ana Uy'],
      );
    });
  });

  group('ang mga header ay header pa rin', () {
    test('hindi napapasok ng bagong panuntunan ang tunay na ingay', () {
      final roster = parseRoster([
        'Confirmed players:',
        'Paid: Mark, Ana, Jun',
        'Thursday July 06 8pm Yspacio',
        'sino ba sasama bukas',
        '---',
      ].join('\n'));

      expect(roster.entries, isEmpty);
      expect(roster.skippedLines.length, 5);
    });
  });
}
