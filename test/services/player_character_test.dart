import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/services/player_character.dart';

void main() {
  group('stability — the property the whole feature rests on', () {
    test('the same name always gives the same face', () {
      final first = characterFor('Maricel Bautista');
      for (var i = 0; i < 50; i++) {
        expect(characterFor('Maricel Bautista'), first);
      }
    });

    test('the seed for a name is a fixed number, not a run-to-run hash', () {
      // Kung mabasag ito dahil sa pagbabago ng hash, magbabago ang mukha ng
      // LAHAT ng manlalaro sa bawat club na gumagamit na ng app. Sinadyang
      // naka-pin ang mga numero: ang pagpalit ng hash ay hindi aksidente.
      expect(characterSeedForName('Maricel'), 839188941);
      expect(characterSeedForName('Jhun'), 3261527);
      expect(characterSeedForName('Bea'), 97406);
    });

    test('spacing and capitalisation do not change the face', () {
      final plain = characterFor('kuya jun');
      expect(characterFor('Kuya Jun'), plain);
      expect(characterFor('  KUYA   JUN  '), plain);
      expect(characterFor('Kuya\tJun'), plain);
    });

    test('different names generally get different faces', () {
      const roster = [
        'Maricel', 'Jhun', 'Bea', 'Rico', 'Neneng', 'Dondon',
        'Aileen', 'Bing', 'Jomar', 'Shiela', 'Tope', 'Evelyn',
      ];
      final faces = roster.map(characterFor).toSet();
      // Hindi tayo nangangako ng perpekto — pero ang isang gabi ay hindi
      // dapat mukhang kambal ang kalahati.
      expect(faces.length, greaterThanOrEqualTo(11));
    });
  });

  group('every index stays inside its palette', () {
    test('across ten thousand seeds, nothing goes out of range', () {
      for (var seed = 0; seed < 10000; seed++) {
        final c = characterFor('ignored', seed: seed);
        expect(c.skin, inInclusiveRange(0, CharacterCounts.skin - 1));
        expect(c.hair, inInclusiveRange(0, CharacterCounts.hair - 1));
        expect(
          c.hairColor,
          inInclusiveRange(0, CharacterCounts.hairColor - 1),
        );
        expect(c.kit, inInclusiveRange(0, CharacterCounts.kit - 1));
        expect(
          c.accessory,
          inInclusiveRange(0, CharacterCounts.accessory - 1),
        );
      }
    });

    test('a name of any shape is survivable', () {
      // Galing sa Messenger paste ang mga pangalan, kaya kung ano-ano ang
      // dumarating. Walang dapat pumutok dito.
      for (final name in ['', ' ', 'A', '🏸', 'Ñoño', 'Jun-Jun P.', 'x' * 500]) {
        final c = characterFor(name);
        expect(c.kit, inInclusiveRange(0, CharacterCounts.kit - 1));
      }
    });

    test('every part of the face actually varies', () {
      // Kung may bahaging naka-stuck sa isang halaga, mukhang pare-pareho
      // ang buong roster at hindi agad halata kung bakit.
      final skins = <int>{};
      final hairs = <int>{};
      final hairColors = <int>{};
      final kits = <int>{};
      final accessories = <int>{};
      for (var seed = 0; seed < 600; seed++) {
        final c = characterFor('ignored', seed: seed);
        skins.add(c.skin);
        hairs.add(c.hair);
        hairColors.add(c.hairColor);
        kits.add(c.kit);
        accessories.add(c.accessory);
      }
      expect(skins.length, CharacterCounts.skin);
      expect(hairs.length, CharacterCounts.hair);
      expect(hairColors.length, CharacterCounts.hairColor);
      expect(kits.length, CharacterCounts.kit);
      expect(accessories.length, CharacterCounts.accessory);
    });
  });

  group('the QM override', () {
    test('a seed wins over the name', () {
      final fromName = characterFor('Maricel');
      final fromSeed = characterFor('Maricel', seed: 12345);
      expect(fromSeed, isNot(fromName));
      // At ang seed ay hindi nakikinig sa pangalan.
      expect(characterFor('Someone else', seed: 12345), fromSeed);
    });

    test('cycling moves to a different face', () {
      const name = 'Maricel';
      final start = characterFor(name);
      final next = characterFor(name, seed: cycledSeed(name, null));
      expect(next, isNot(start));
    });

    test('cycling enough times comes back around without crashing', () {
      const name = 'Jhun';
      int? seed;
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        seed = cycledSeed(name, seed);
        expect(seed, inInclusiveRange(0, 2147483646));
        seen.add(seed);
      }
      expect(seen.length, 200, reason: 'bawat pindot ay bagong buto');
    });

    test('one tap does not leave the shirt the same colour', () {
      // ANG BUG NA NAHULI NG CONTACT SHEET: ang Lehmer ay linear, kaya ang
      // buto na `s` at `s+1` ay may pare-parehong agwat — at ang agwat na
      // iyon modulo anim ay isang maikling siklo. Sa sinukat: **89%** ng
      // magkasunod na buto ay may PAREHONG kulay ng damit. Pinipindot ng
      // QM ang "iba naman" at halos hindi nagbabago ang kulay.
      //
      // Hindi ito sinusukat kada-anim-na-bintana: ang mabuting hash ay
      // minsan talagang nagbibigay ng sunod-sunod na pareho, at hindi iyon
      // bug. Ang sinusukat ay ang **istruktura** — gaano kadalas sumunod
      // ang kapareho. Ang random ay 1-sa-6, mga 16.7%.
      var same = 0;
      const span = 4000;
      for (var seed = 1; seed <= span; seed++) {
        if (characterFor('x', seed: seed).kit ==
            characterFor('x', seed: seed - 1).kit) {
          same++;
        }
      }
      final rate = same / span;
      expect(
        rate,
        lessThan(0.30),
        reason: 'magkasunod na parehong kulay: '
            '${(rate * 100).toStringAsFixed(1)}% (random ay ~16.7%, '
            'ang lumang bug ay 89%)',
      );
    });

    test('every tap visibly changes the face', () {
      // Mga apat sa bawat labindalawang libong buto ang nagbibigay ng
      // eksaktong parehong mukha sa kasunod. Bihira — pero kapag nangyari,
      // pinindot ng QM ang pindutan at walang nangyari, at mukhang sira
      // ang app. Lumulukso ang cycledSeed para hindi ito mangyari.
      const name = 'Jhun';
      var seed = characterSeedForName(name);
      for (var tap = 0; tap < 3000; tap++) {
        final before = characterFor(name, seed: seed);
        seed = cycledSeed(name, seed);
        expect(
          characterFor(name, seed: seed),
          isNot(before),
          reason: 'pindot $tap ay walang ginawa',
        );
      }
    });

    test('cycling reaches a good spread of faces, not two that alternate', () {
      const name = 'Bea';
      int? seed;
      final faces = <PlayerCharacter>{};
      for (var i = 0; i < 40; i++) {
        seed = cycledSeed(name, seed);
        faces.add(characterFor(name, seed: seed));
      }
      expect(faces.length, greaterThanOrEqualTo(30));
    });
  });

  test('there are enough faces for the biggest night', () {
    expect(CharacterCounts.total, greaterThan(1000));
  });
}
