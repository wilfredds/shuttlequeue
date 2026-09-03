import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/club_member.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/services/name_matcher.dart';

ClubMember member(
  String name, {
  List<String> aliases = const [],
  SkillTier tier = SkillTier.intermediate,
}) {
  return ClubMember(
    id: 'id-$name',
    name: name,
    skillTier: tier,
    aliases: aliases,
    balanceCentavos: 0,
    sessionsAttended: 4,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('normalizeName', () {
    test('strips Filipino honorifics', () {
      expect(normalizeName('Kuya Jun'), 'jun');
      expect(normalizeName('Ate Ana'), 'ana');
      expect(normalizeName('Tita Rica'), 'rica');
      expect(normalizeName('Coach Hazel'), 'hazel');
    });

    test('keeps an honorific when it is the whole name', () {
      // Baka "Ate" talaga ang tawag sa kanya sa grupo.
      expect(normalizeName('Ate'), 'ate');
    });

    test('strips punctuation and collapses spaces', () {
      expect(normalizeName('JUN   P.'), 'jun p');
      expect(normalizeName('Ana-Marie'), 'ana marie');
    });

    test('keeps accented letters — they are part of the name', () {
      expect(normalizeName('Niña'), 'niña');
      expect(normalizeName('José'), 'josé');
    });
  });

  group('exact matches', () {
    test('matches an identical name', () {
      final result = matchMember('Jun', [member('Jun'), member('Ana')]);
      expect(result.confidence, MatchConfidence.exact);
      expect(result.member?.name, 'Jun');
      expect(result.isConfident, isTrue);
    });

    test('matches through a remembered alias', () {
      final members = [member('Jun', aliases: ['Kuya Jun', 'JP'])];
      expect(matchMember('JP', members).confidence, MatchConfidence.exact);
      expect(matchMember('Kuya Jun', members).confidence, MatchConfidence.exact);
    });

    test('honorifics do not block a match', () {
      final result = matchMember('Kuya Jun', [member('Jun')]);
      expect(result.confidence, MatchConfidence.exact);
    });

    test('case and punctuation do not block a match', () {
      expect(matchMember('  jUn  ', [member('Jun')]).confidence,
          MatchConfidence.exact);
    });
  });

  group('likely matches', () {
    test('a first name matches a fuller name', () {
      final result = matchMember('Jun', [member('Jun Padilla'), member('Ana')]);
      expect(result.confidence, MatchConfidence.likely);
      expect(result.member?.name, 'Jun Padilla');
    });

    test('a fuller name matches a stored first name', () {
      final result = matchMember('Jun P.', [member('Jun'), member('Ana')]);
      expect(result.confidence, MatchConfidence.likely);
    });

    test('a single-letter typo is forgiven on longer names', () {
      final result = matchMember('Poalo', [member('Paolo')]);
      expect(result.confidence, MatchConfidence.likely);
    });

    test('short names are NOT typo-matched — too risky', () {
      // "Ana" and "Ann" are one edit apart but are different people.
      final result = matchMember('Ann', [member('Ana')]);
      expect(result.confidence, MatchConfidence.none);
    });
  });

  group('ambiguity — R-07, never guess', () {
    test('two members named Jun produce an ambiguous result, not a pick', () {
      final members = [
        member('Jun', tier: SkillTier.advanced),
        member('Jun', tier: SkillTier.beginner),
      ];
      final result = matchMember('Jun', members);

      expect(result.confidence, MatchConfidence.ambiguous);
      expect(result.member, isNull, reason: 'must not choose for the QM');
      expect(result.alternatives.length, 2);
      expect(result.isConfident, isFalse);
    });

    test('two members sharing a first name are ambiguous', () {
      final members = [member('Jun Padilla'), member('Jun Reyes')];
      final result = matchMember('Jun', members);
      expect(result.confidence, MatchConfidence.ambiguous);
      expect(result.alternatives.length, 2);
    });
  });

  group('no match', () {
    test('a brand new player matches nobody', () {
      final result = matchMember('Newcomer', [member('Jun'), member('Ana')]);
      expect(result.confidence, MatchConfidence.none);
      expect(result.member, isNull);
    });

    test('an empty roster matches nobody', () {
      expect(matchMember('Jun', const []).confidence, MatchConfidence.none);
    });

    test('empty input never crashes', () {
      expect(matchMember('', [member('Jun')]).confidence, MatchConfidence.none);
      expect(matchMember('   ', [member('Jun')]).confidence,
          MatchConfidence.none);
    });
  });

  group('editDistance', () {
    test('counts single edits', () {
      // Transposition ay ISANG pagbabago — Damerau-Levenshtein, hindi payak.
      expect(editDistance('paolo', 'poalo'), 1);
      expect(editDistance('paolo', 'paulo'), 1); // substitution
      expect(editDistance('jun', 'jon'), 1);
      expect(editDistance('ana', 'ana'), 0);
      expect(editDistance('', 'abc'), 3);
    });
  });

  group('the payoff — week two is faster than week one', () {
    test('a returning regular arrives with their skill tier remembered', () {
      final regulars = [
        member('Jun', aliases: ['Kuya Jun'], tier: SkillTier.advanced),
        member('Ana', tier: SkillTier.beginner),
      ];

      final jun = matchMember('Kuya Jun', regulars);
      expect(jun.isConfident, isTrue);
      expect(jun.member?.skillTier, SkillTier.advanced);

      final ana = matchMember('ana', regulars);
      expect(ana.isConfident, isTrue);
      expect(ana.member?.skillTier, SkillTier.beginner);
    });
  });
}
