/// Kung anong mukha ang ibibigay sa isang pangalan.
///
/// Puro Dart — walang Flutter, walang `Color`. Ang service ay nagbibigay ng
/// mga **index** lang; ang `widgets/player_avatar.dart` ang may hawak ng
/// tunay na kulay. Kaya masusubok ito nang walang widget tester, at kaya
/// hindi nagkakalat ng kulay sa labas ng design system.
///
/// TATLONG PANUNTUNAN ANG BUMUO NITO:
///
///  1. **Matatag.** Si Maricel ay may isang mukha lang — ngayong gabi at sa
///     gabi sa susunod na buwan. Isang listahan ng labindalawang pangalan
///     ang binabasa nang pabalik-balik sa loob ng apat na oras; ang mukhang
///     nagbabago kada refresh ay mas masahol pa sa walang mukha.
///  2. **Hindi hinuhulaan ang kasarian.** Ang app ay may pangalan lang —
///     walang kasarian sa roster, at sinasadya iyon (RA 10173, tingnan ang
///     `club_member.dart`). Ang "Jhun", "Bing", "Neneng", "Jo" ay pwedeng
///     kahit alin. Kaya ang hash ay bulag: hindi ito nagmumula sa kasarian
///     at hindi ito humuhula. Kapag mali ang napunta, isang pindot lang ang
///     pagpalit — tingnan ang [cycledSeed].
///  3. **Nababasa sa 24 pixel.** Hugis ang pinagkaiba, hindi detalye. Sa
///     taas ng isang hilera sa pila, ang buhok at ang kulay ng damit ang
///     tanging nakikita — kaya iyon ang may pinakamaraming pagpipilian.
library;

/// Gaano karaming pagpipilian sa bawat bahagi.
///
/// Dito nakasulat ang bilang, hindi sa painter: ang service ang pumipili,
/// kaya ang service ang dapat makaalam kung ilan ang mapagpipilian. May
/// assert sa `player_avatar.dart` na tinitiyak na pareho ang laki ng
/// kanyang palette — kapag nagdagdag ka ng kulay doon at nakalimutan dito,
/// hindi mapipili ang bago.
abstract final class CharacterCounts {
  static const int skin = 4;
  static const int hair = 8;
  static const int hairColor = 4;
  static const int kit = 6;
  static const int accessory = 4;

  /// Ilang magkakaibang mukha ang posible. Sa pinakamalaking gabi (24 tao),
  /// halos imposibleng magkapareho ang dalawa.
  static const int total = skin * hair * hairColor * kit * accessory;
}

/// Ang mukha ng isang manlalaro, bilang mga index.
class PlayerCharacter {
  const PlayerCharacter({
    required this.skin,
    required this.hair,
    required this.hairColor,
    required this.kit,
    required this.accessory,
  });

  final int skin;

  /// Hugis ng buhok. **Walang kasarian ang mga hugis** at sinasadyang
  /// hindi nakapangkat — ang 0 ay hindi "pang-lalaki" at ang 4 ay hindi
  /// "pang-babae". Isang hanay lang sila ng hugis na magkakaiba sa 24px.
  final int hair;

  final int hairColor;

  /// Kulay ng damit. Ito ang pinakamalaking patse ng kulay sa avatar, kaya
  /// ito ang unang nakikita sa malayo — sa board sa kabilang dulo ng gym.
  final int kit;

  final int accessory;

  @override
  bool operator ==(Object other) =>
      other is PlayerCharacter &&
      other.skin == skin &&
      other.hair == hair &&
      other.hairColor == hairColor &&
      other.kit == kit &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(skin, hair, hairColor, kit, accessory);

  @override
  String toString() =>
      'PlayerCharacter(skin: $skin, hair: $hair, hairColor: $hairColor, '
      'kit: $kit, accessory: $accessory)';
}

/// Ang mukha para sa isang pangalan, o para sa isang pinili ng QM.
///
/// Kapag may [seed], iyon ang masusunod at hindi na ang pangalan — ito ang
/// pinindot ng QM nang sabihin niyang "hindi ganyan ang mukha niya".
PlayerCharacter characterFor(String name, {int? seed}) {
  final random = _Lehmer(seed ?? characterSeedForName(name));
  return PlayerCharacter(
    skin: random.next(CharacterCounts.skin),
    hair: random.next(CharacterCounts.hair),
    hairColor: random.next(CharacterCounts.hairColor),
    kit: random.next(CharacterCounts.kit),
    accessory: random.next(CharacterCounts.accessory),
  );
}

/// Ang panimulang buto ng isang pangalan.
///
/// Hindi ginagamit ang `String.hashCode`: hindi ito pinapangako ng Dart na
/// pareho sa bawat plataporma at bawat bersyon. Ang web build at ang
/// Android build ay titingin sa **isang** Firestore doc; kung iba ang
/// hash sa dalawa, iba ang mukha ni Maricel sa telepono ng QM at sa board
/// sa dingding. Kaya sarili nating hash, nakasulat dito, hindi nagbabago.
int characterSeedForName(String name) {
  // "  Kuya  JUN  " at "kuya jun" ay iisang tao sa mata ng QM.
  final normalised = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // Polynomial hash modulo 2^31-1. Sinadya ang modulo sa bawat hakbang:
  // sa web, ang Dart `int` ay JS number, kaya ang anumang lumampas sa 2^53
  // ay tahimik na nawawalan ng katumpakan. Ang pinakamalaking pansamantala
  // dito ay 2^31 * 31 + 65535 — mga 6.6e10, ligtas na ligtas.
  var hash = 0;
  for (final unit in normalised.codeUnits) {
    hash = (hash * 31 + unit) % _modulus;
  }
  return hash;
}

/// Ang susunod na mukha kapag pinindot ng QM ang "iba naman".
///
/// Umiikot ito sa buong hanay at bumabalik sa simula, kaya walang dulo at
/// walang masasayang na pindot.
///
/// LUMULUKSO ITO HANGGANG TALAGANG MAG-IBA ANG MUKHA. Mga apat sa bawat
/// labindalawang libong buto ang nagbibigay ng eksaktong parehong mukha sa
/// kasunod nito — bihira, pero kapag nangyari, pinindot ng QM ang pindutan
/// at walang nangyari. Mas masahol pa iyon kaysa sa maling mukha: mukhang
/// sira ang app. May hangganan ang paghahanap kaya hindi ito mabibitag.
int cycledSeed(String name, int? currentSeed) {
  final base = currentSeed ?? characterSeedForName(name);
  final current = characterFor(name, seed: base);

  var next = (base + 1) % _modulus;
  for (var i = 0; i < 8; i++) {
    if (characterFor(name, seed: next) != current) break;
    next = (next + 1) % _modulus;
  }
  return next;
}

const int _modulus = 2147483647; // 2^31 - 1, prime.

/// Lehmer / Park-Miller. Maliit, walang state sa labas, at **pareho ang
/// resulta sa Android at sa web** — iyon ang buong dahilan kung bakit hindi
/// `dart:math` Random ang gamit dito (walang pangako ang algorithm nito sa
/// pagitan ng mga bersyon ng Dart).
class _Lehmer {
  _Lehmer(int seed) : _state = _mix(seed);

  int _state;

  /// Binabasag ang linearidad bago ang unang draw.
  ///
  /// BAKIT KAILANGAN ITO: ang Lehmer ay linear, kaya ang buto na `s` at
  /// `s+1` ay laging may parehong agwat — at ang agwat na iyon modulo anim
  /// (ang bilang ng kulay ng damit) ay isang maikling siklo. Ang nakita ko
  /// sa contact sheet: tatlong sunod-sunod na lila, tapos tatlong sunod-
  /// sunod na rosas. Dahil ang "iba naman" ng QM ay `seed + 1`, ang bawat
  /// pindot niya ay magbibigay ng halos parehong kulay — at ang mismong
  /// pindot na iyon ay para mag-iba.
  ///
  /// Ang xor-shift sa gitna ang bumabasag nito. Lahat ng hakbang ay nasa
  /// ilalim ng 2^53 kaya tumpak pa rin sa web: ang pinakamalaki ay
  /// (2^31) * 16807 ≈ 3.6e13.
  static int _mix(int seed) {
    var x = seed.abs() % _modulus;
    x = (x * 48271) % _modulus;
    x = (x ^ (x >> 7)) % _modulus;
    x = (x * 16807) % _modulus;
    return x % (_modulus - 1) + 1;
  }

  /// Susunod na bilang sa 0..[bound)-1.
  ///
  /// Ang pinakamalaking pansamantala ay (2^31-2) * 48271 ≈ 1.04e14, nasa
  /// ilalim pa rin ng 2^53 — kaya tumpak ito kahit sa web.
  int next(int bound) {
    _state = (_state * 48271) % _modulus;
    return _state % bound;
  }
}
