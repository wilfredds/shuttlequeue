import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/repositories/deferred_write.dart';

/// Dalawang maliit na pure function na parehong nagbabantay sa isang
/// katahimikang bug: isang mali na hindi nagpapakita ng error, kaya
/// aakalain mong maayos ang lahat hanggang mawala na ang datos.
void main() {
  ClubCandidate club(
    String id, {
    DateTime? createdAt,
    int members = 0,
    String? gcash,
  }) =>
      (
        id: id,
        createdAt: createdAt,
        memberCount: members,
        gcashNumber: gcash,
      );

  group('pickPrimaryClub — kapag nadoble ang club', () {
    test('walang kandidato, walang sagot', () {
      expect(pickPrimaryClub(const []), isNull);
    });

    test('isa lang, iyon na — at walang kukumpunihin', () {
      final choice = pickPrimaryClub([club('aaa', members: 8)]);
      expect(choice!.id, 'aaa');
      expect(choice.adoptGcash, isNull);
    });

    test('ang may pinakamaraming regular ang panalo, kahit mas bata', () {
      // Ang regulars book ang hindi na mababawi: may tier, palayaw at
      // balanse ang bawat isa. Hindi iyon katumbas ng walang lamang club
      // na mas matanda lang.
      final choice = pickPrimaryClub([
        club('walang-laman', createdAt: DateTime(2026, 7, 1)),
        club('may-regulars', createdAt: DateTime(2026, 9, 1), members: 8),
      ]);
      expect(choice!.id, 'may-regulars');
    });

    test('pantay na miyembro: ang mas matanda ang panalo', () {
      final choice = pickPrimaryClub([
        club('bago', createdAt: DateTime(2026, 9, 6), members: 3),
        club('luma', createdAt: DateTime(2026, 7, 7), members: 3),
      ]);
      expect(choice!.id, 'luma');
    });

    test('hindi nakadepende sa pagkakasunod ng pagdating', () {
      final a = club('luma', createdAt: DateTime(2026, 7, 7), members: 3);
      final b = club('bago', createdAt: DateTime(2026, 9, 6), members: 3);
      expect(pickPrimaryClub([a, b])!.id, pickPrimaryClub([b, a])!.id);
    });

    test('ang hindi pa naka-sync (walang createdAt) ay pinakabago', () {
      final choice = pickPrimaryClub([
        club('kagagawa-lang'),
        club('luma', createdAt: DateTime(2026, 7, 7)),
      ]);
      expect(choice!.id, 'luma');
    });

    test('kung pawang walang createdAt, ang ID ang tie-break', () {
      expect(pickPrimaryClub([club('zzz'), club('aaa')])!.id, 'aaa');
      expect(pickPrimaryClub([club('aaa'), club('zzz')])!.id, 'aaa');
    });
  });

  group('pickPrimaryClub — sinasagip ang naulilang GCash number', () {
    test('ang totoong kaso: hati ang kasaysayan sa tatlong club', () {
      // Eksaktong datos na natagpuan sa Firebase noong 2026-09-06: walong
      // regular sa pinakamatanda, ang GCash number sa pangalawa, at isang
      // bagong walang laman. Dapat mabawi ang PAREHO.
      final choice = pickPrimaryClub([
        club('NK7G', createdAt: DateTime(2026, 9, 5, 13, 54), members: 8),
        club('mvhV',
            createdAt: DateTime(2026, 9, 6, 5, 47), gcash: '09293656299'),
        club('taBQ', createdAt: DateTime(2026, 9, 6, 12, 35)),
      ]);
      expect(choice!.id, 'NK7G', reason: 'doon ang walong regular');
      expect(choice.adoptGcash, '09293656299', reason: 'sagipin ang numero');
    });

    test('may numero na ang napili — huwag nang galawin', () {
      final choice = pickPrimaryClub([
        club('napili', members: 8, gcash: '09171234567'),
        club('naulit', gcash: '09293656299'),
      ]);
      expect(choice!.id, 'napili');
      expect(choice.adoptGcash, isNull);
    });

    test('magkaibang numero sa mga naulit: hindi tayo manghuhula', () {
      // Kapareho ng NameMatcher: mas mabuting walang laman kaysa maling
      // numero — doon mapupunta ang bayad ng mga manlalaro.
      final choice = pickPrimaryClub([
        club('napili', members: 8),
        club('naulit-a', gcash: '09171111111'),
        club('naulit-b', gcash: '09292222222'),
      ]);
      expect(choice!.id, 'napili');
      expect(choice.adoptGcash, isNull);
    });

    test('pareho ang numero sa dalawang naulit: hindi malabo, sagipin', () {
      final choice = pickPrimaryClub([
        club('napili', members: 8),
        club('naulit-a', gcash: '09293656299'),
        club('naulit-b', gcash: '09293656299'),
      ]);
      expect(choice!.adoptGcash, '09293656299');
    });

    test('walang numero kahit saan: wala ring kukumpunihin', () {
      final choice = pickPrimaryClub([
        club('napili', members: 8),
        club('naulit'),
      ]);
      expect(choice!.adoptGcash, isNull);
    });
  });

  group('naturalCompare — "Court 2" bago ang "Court 10"', () {
    test('ang plain string sort ay mali; ito ay tama', () {
      final labels = ['Court 10', 'Court 2', 'Court 1'];

      final wrong = [...labels]..sort();
      expect(wrong.last, 'Court 2', reason: 'ito ang bug na inaayos natin');

      final right = [...labels]..sort(naturalCompare);
      expect(right, ['Court 1', 'Court 2', 'Court 10']);
    });

    test('mahigit sampu, tuloy pa rin ang tamang pagkakasunod', () {
      final labels = ['Court 3', 'Court 21', 'Court 12', 'Court 100'];
      expect(
        [...labels]..sort(naturalCompare),
        ['Court 3', 'Court 12', 'Court 21', 'Court 100'],
      );
    });

    test('kapag pinalitan ng QM ang pangalan, alpabeto na lang', () {
      final labels = ['Likod', 'Harap', 'Gitna'];
      expect([...labels]..sort(naturalCompare), ['Gitna', 'Harap', 'Likod']);
    });

    test('may numero at wala: hindi nag-crash, deterministiko pa rin', () {
      final labels = ['Court 2', 'Main', 'Court 1'];
      final sorted = [...labels]..sort(naturalCompare);
      expect(sorted.length, 3);
      expect(sorted.indexOf('Court 1'), lessThan(sorted.indexOf('Court 2')));
    });
  });
}
