/// Ang mukha ng isang manlalaro, iginuguhit sa canvas.
///
/// BAKIT IGINUGUHIT AT HINDI LARAWAN: ang app na ito ay tumatakbo nang apat
/// na oras na walang internet, at ang mga font ay sinadyang i-subset para
/// makatipid ng 400 KB. Ang dalawampu't apat na PNG ay sisira sa dalawang
/// bagay na iyon. Isang painter, walang byte sa network, kahit anong laki.
/// Pareho ang pasya sa `shuttle_mark.dart`.
///
/// KUNG PAANO ITO NABABASA SA 24 PIXEL: hugis ang pinagkaiba, hindi detalye.
/// Sa taas ng isang hilera sa pila, tatlong bagay lang ang umaabot sa mata —
/// ang kulay ng disc, ang kulay ng damit, at ang anyo ng buhok. Doon napunta
/// ang lahat ng pagpipilian. Ang mata at bibig ay nandiyan para maging tao
/// ito, hindi para mabasa.
///
/// Ang pagpili ng mukha ay nasa `services/player_character.dart` — purong
/// Dart at may test. Dito lang ang kulay at ang guhit.
library;

import 'package:flutter/material.dart';

import '../services/player_character.dart';
import '../theme.dart';
import 'motion.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
//
// SINADYANG WALA DITO ang court green, ang amber ng `attention`, ang pula ng
// `alarm`, at ang tatlong kulay ng skill tier. May trabaho na ang bawat isa
// sa kanila sa app; kapag nagsuot ng amber ang isang manlalaro, nawawala ang
// kahulugan ng amber sa lahat ng iba. Ito ang bakanteng bahagi ng palette.

/// Kulay ng damit — ang pinakamalaking patse, kaya ito ang nakikita sa
/// kabilang dulo ng gym.
const List<Color> _kit = [
  Color(0xFF0E7490), // cyan
  Color(0xFF4338CA), // indigo
  Color(0xFF9D174D), // rose
  Color(0xFF475569), // slate
  Color(0xFF6D28D9), // violet
  Color(0xFF8A4B12), // tanned brown
];

/// Apat na hakbang, hindi dalawa. Isang club sa Imus ang gumagamit nito.
const List<Color> _skin = [
  Color(0xFFF7D9BC),
  Color(0xFFE8BC93),
  Color(0xFFC78B5C),
  Color(0xFF96603A),
];

/// Karamihan ay itim at kayumanggi; may dalawang mas mapusyaw para sa
/// nagkukulay ng buhok. Hindi ito pang-dekorasyon — ito ang pumipigil sa
/// roster na magmukhang isang tao na kinopya nang labindalawang beses.
const List<Color> _hairColors = [
  Color(0xFF1B1310),
  Color(0xFF32201A),
  Color(0xFF54331F),
  Color(0xFF8A5A33),
];

/// Iginuguhit ang mukha nang diretso sa isang [Canvas], sa (0,0) hanggang
/// ([size], [size]).
///
/// Nakabukas ito para sa `test/avatar_contact_sheet.dart`, ang kasangkapang
/// gumagawa ng contact sheet ng lahat ng mukha — mas madali tingnan ng mata
/// ang isang PNG kaysa pag-isipan kung ano ang hitsura ng walong anyo ng
/// buhok. Hindi ito kailangan ng app mismo; gamitin ang [PlayerAvatar].
void paintPlayerCharacter({
  required Canvas canvas,
  required double size,
  required String name,
  int? seed,
  Color? ringColor,
}) {
  _CharacterPainter(
    character: characterFor(name, seed: seed),
    ringColor: ringColor,
  ).paint(canvas, Size.square(size));
}

/// Ang mukha ng isang manlalaro.
///
/// Ibigay ang [name] at, kung may pinili ang QM, ang [seed]. Ang [ringColor]
/// ay para sa skill tier: iisang elemento ang nagdadala ng dalawang trabaho,
/// kaya hindi lumalaki ang hilera sa pila.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.seed,
    this.size = 28,
    this.ringColor,
  });

  final String name;
  final int? seed;
  final double size;

  /// Kapag may laman, may singsing sa paligid ng disc. Ginagamit sa skill
  /// tier sa pila, kung saan walang espasyo para sa hiwalay na badge.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    // Ang pangalan ay nasa tabi nito bilang tunay na teksto sa lahat ng
    // lugar na ginagamit ito, kaya walang dapat basahin dito ang screen
    // reader. Pareho sa ShuttleMark.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _CharacterPainter(
            character: characterFor(name, seed: seed),
            ringColor: ringColor,
          ),
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter({required this.character, this.ringColor});

  final PlayerCharacter character;
  final Color? ringColor;

  // Tinitiyak na kasabay na lumaki ang palette at ang bilang na alam ng
  // service. Kapag nagdagdag ka ng kulay dito at nakalimutan sa
  // CharacterCounts, hindi kailanman mapipili ang bago — at walang
  // magsasabi sa iyo.
  static bool _paletteCheck() {
    assert(_kit.length == CharacterCounts.kit);
    assert(_skin.length == CharacterCounts.skin);
    assert(_hairColors.length == CharacterCounts.hairColor);
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    assert(_paletteCheck());

    final s = size.shortestSide;
    final kit = _kit[character.kit];
    final skin = _skin[character.skin];
    final hair = _hairColors[character.hairColor];

    // Lahat ng guhit ay nasa unit coordinates (0..1) at saka pinapalaki.
    // Kaya pareho ang hitsura sa 20px at sa 96px, at nasa isang lugar lang
    // ang mga numero kapag may inaayos.
    Offset p(double x, double y) => Offset(x * s, y * s);
    double u(double v) => v * s;

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final disc = Rect.fromCircle(center: p(0.5, 0.5), radius: u(0.5));

    canvas.save();
    canvas.clipPath(Path()..addOval(disc));

    // 1. Ang disc. Ang kulay ng damit na pinalabnaw — ito ang unang
    //    nakikita, bago pa ang anumang hugis.
    fill.color = Color.alphaBlend(
      kit.withValues(alpha: 0.16),
      const Color(0xFFFFFFFF),
    );
    canvas.drawOval(disc, fill);

    // 2. Buhok na nasa LIKOD ng ulo (mahaba, bob, ponytail). Nauuna ito
    //    para lumabas ang ulo sa harap nito.
    _paintHairBehind(canvas, p, u, hair);

    // 3. Leeg.
    fill.color = _shade(skin, 0.90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(u(0.425), u(0.58), u(0.575), u(0.78)),
        Radius.circular(u(0.05)),
      ),
      fill,
    );

    // 4. Balikat at damit. Isang burol na tumutubo mula sa ibaba; ang
    //    tuktok nito ay nasa y = 0.70.
    fill.color = kit;
    canvas.drawOval(
      Rect.fromCircle(center: p(0.5, 1.13), radius: u(0.43)),
      fill,
    );
    // Kwelyo — isang guhit lang, pero ito ang nagpapamukhang damit sa
    // burol imbes na basta kulay.
    stroke
      ..color = _shade(kit, 0.78)
      ..strokeWidth = u(0.028);
    canvas.drawPath(
      Path()
        ..moveTo(u(0.40), u(0.735))
        ..quadraticBezierTo(u(0.5), u(0.83), u(0.60), u(0.735)),
      stroke,
    );

    // 5. Tenga.
    fill.color = _shade(skin, 0.93);
    canvas.drawCircle(p(0.287, 0.475), u(0.042), fill);
    canvas.drawCircle(p(0.713, 0.475), u(0.042), fill);

    // 6. Ulo.
    fill.color = skin;
    canvas.drawOval(
      Rect.fromCenter(
        center: p(0.5, 0.45),
        width: u(0.44),
        height: u(0.485),
      ),
      fill,
    );

    // 7. Mata at bibig. Hindi ito para mabasa sa 24px — para hindi ito
    //    magmukhang bola na may buhok.
    fill.color = const Color(0xFF26201C);
    canvas.drawCircle(p(0.437, 0.470), u(0.0255), fill);
    canvas.drawCircle(p(0.563, 0.470), u(0.0255), fill);

    stroke
      ..color = _shade(skin, 0.58)
      ..strokeWidth = u(0.022);
    canvas.drawPath(
      Path()
        ..moveTo(u(0.462), u(0.553))
        ..quadraticBezierTo(u(0.5), u(0.581), u(0.538), u(0.553)),
      stroke,
    );

    // 8. Buhok na nasa HARAP ng ulo.
    _paintHairFront(canvas, p, u, hair, skin);

    // 9. Ang isinusuot: headband, cap, salamin, o wala.
    _paintAccessory(canvas, p, u, kit);

    canvas.restore();

    // 10. Singsing ng skill tier, nasa labas ng clip para buo ang guhit.
    if (ringColor != null) {
      canvas.drawOval(
        disc.deflate(u(0.045)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u(0.075)
          ..color = ringColor!,
      );
    } else {
      // Walang singsing: isang manipis na hangganan pa rin, kung hindi ay
      // nalulusaw ang mapusyaw na disc sa puting kard.
      canvas.drawOval(
        disc.deflate(u(0.02)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u(0.035)
          ..color = _shade(kit, 0.80).withValues(alpha: 0.38),
      );
    }
  }

  /// Ang mga anyo ng buhok na nasa likod ng ulo.
  ///
  /// WALANG KASARIAN ANG MGA ANYO. Ang 0 ay hindi "pang-lalaki" at ang 5 ay
  /// hindi "pang-babae" — isang hanay lang sila ng hugis na magkakaiba sa
  /// 24 pixel. Tingnan ang paliwanag sa player_character.dart.
  void _paintHairBehind(
    Canvas canvas,
    Offset Function(double, double) p,
    double Function(double) u,
    Color hair,
  ) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = hair;

    switch (character.hair) {
      case 3: // Ponytail — isang buhol sa likod, bahagyang nakatagilid.
        canvas.drawOval(
          Rect.fromCenter(
            center: p(0.805, 0.47),
            width: u(0.20),
            height: u(0.26),
          ),
          fill,
        );
      case 5: // Mahaba at nakalugay, lampas panga.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(u(0.235), u(0.30), u(0.765), u(0.80)),
            Radius.circular(u(0.24)),
          ),
          fill,
        );
      case 7: // Bob — hanggang panga lang.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(u(0.245), u(0.285), u(0.755), u(0.635)),
            Radius.circular(u(0.22)),
          ),
          fill,
        );
      default:
        break;
    }
  }

  void _paintHairFront(
    Canvas canvas,
    Offset Function(double, double) p,
    double Function(double) u,
    Color hair,
    Color skin,
  ) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = hair;

    // Ang pangunahing takip: tuktok ng ulo mula sa kaliwang sentido
    // papunta sa kanan. Ito ang batayan ng halos lahat ng anyo.
    Path cap({double top = 0.195, double drop = 0.46, double side = 0.235}) {
      return Path()
        ..moveTo(u(side), u(drop))
        ..cubicTo(
          u(side - 0.01), u(top + 0.04),
          u(1 - side + 0.01), u(top + 0.04),
          u(1 - side), u(drop),
        )
        ..cubicTo(
          u(1 - side - 0.03), u(drop - 0.17),
          u(side + 0.03), u(drop - 0.17),
          u(side), u(drop),
        )
        ..close();
    }

    // ANG NATUTUNAN SA CONTACT SHEET: sa 26px, ang pinagkaiba ay dapat
    // **silhouette**, hindi tekstura. Ang unang bersyon ay walong bahagyang
    // magkaibang takip, at sa laki ng hilera sa pila, lahat sila ay iisang
    // bilog na itim. Kaya ngayon, bawat isa ay may hiwalay na balangkas:
    // taas, lapad, o may idinagdag na hugis sa labas ng ulo.
    switch (character.hair) {
      case 0: // Mataas ang tuktok — may bangs na nakatayo.
        canvas.drawPath(cap(top: 0.125, drop: 0.43), fill);
      case 1: // Hati sa gilid. Ang hiwa ang nagpapakilala nito, hindi
        //      ang taas — kaya malinaw ito kahit maliit.
        canvas.drawPath(cap(top: 0.185), fill);
        canvas.drawPath(
          Path()
            ..moveTo(u(0.375), u(0.215))
            ..quadraticBezierTo(u(0.345), u(0.33), u(0.395), u(0.425))
            ..lineTo(u(0.325), u(0.425))
            ..quadraticBezierTo(u(0.300), u(0.32), u(0.330), u(0.225))
            ..close(),
          Paint()..color = skin,
        );
      case 2: // Buzz — dikit sa bungo at makitid.
        canvas.drawPath(cap(top: 0.270, drop: 0.385, side: 0.262), fill);
      case 3: // Ponytail — ang buhol ay nasa _paintHairBehind.
        canvas.drawPath(cap(top: 0.195), fill);
      case 4: // Bun sa tuktok.
        canvas.drawPath(cap(top: 0.215), fill);
        canvas.drawCircle(p(0.5, 0.150), u(0.100), fill);
      case 5: // Mahaba — ang panel sa likod ang nagpapakilala.
        canvas.drawPath(cap(top: 0.185), fill);
      case 6: // Kulot — scalloped na balangkas.
        for (final x in const [0.288, 0.394, 0.5, 0.606, 0.712]) {
          canvas.drawCircle(p(x, 0.248), u(0.108), fill);
        }
        canvas.drawCircle(p(0.252, 0.352), u(0.086), fill);
        canvas.drawCircle(p(0.748, 0.352), u(0.086), fill);
      case 7: // Bob — pantay at mababa ang bangs.
        canvas.drawPath(cap(top: 0.205, drop: 0.385), fill);
      default:
        canvas.drawPath(cap(), fill);
    }
  }

  void _paintAccessory(
    Canvas canvas,
    Offset Function(double, double) p,
    double Function(double) u,
    Color kit,
  ) {
    switch (character.accessory) {
      case 1: // Headband. Isang guhit sa noo — nababasa kahit sa 20px.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(u(0.255), u(0.325), u(0.745), u(0.395)),
            Radius.circular(u(0.035)),
          ),
          Paint()..color = _lift(kit),
        );
      case 2: // Cap. Dome at labi sa kanan.
        final dome = Path()
          ..moveTo(u(0.235), u(0.385))
          ..cubicTo(
            u(0.235), u(0.145),
            u(0.765), u(0.145),
            u(0.765), u(0.385),
          )
          ..close();
        canvas.drawPath(dome, Paint()..color = _lift(kit));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(u(0.60), u(0.345), u(0.90), u(0.415)),
            Radius.circular(u(0.035)),
          ),
          Paint()..color = _shade(_lift(kit), 0.80),
        );
      case 3: // Sports glasses. Maliit at manipis.
        //
        // NAHULI SA CONTACT SHEET: sa 0.082 na radius, nagdidikit ang
        // dalawang lente at nagiging isang goggles na tumatakip sa buong
        // mukha — at nasa isang kapat ng roster ito. Ang salamin ay dapat
        // palamuti sa mukha, hindi kapalit nito.
        final lens = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u(0.019)
          ..color = const Color(0xFF3A322C);
        canvas.drawOval(
          Rect.fromCenter(
            center: p(0.437, 0.470),
            width: u(0.115),
            height: u(0.098),
          ),
          lens,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: p(0.563, 0.470),
            width: u(0.115),
            height: u(0.098),
          ),
          lens,
        );
        canvas.drawLine(p(0.4945, 0.470), p(0.5055, 0.470), lens);
      default:
        break;
    }
  }

  /// Pinapadilim ang kulay nang [factor] — para sa anino, kwelyo, tenga.
  static Color _shade(Color base, double factor) {
    return Color.from(
      alpha: base.a,
      red: base.r * factor,
      green: base.g * factor,
      blue: base.b * factor,
    );
  }

  /// Pinapaliwanag ang kulay ng damit para sa isinusuot. Ang headband na
  /// kasing-dilim ng buhok ay hindi makikita; kailangan nitong tumalbog.
  static Color _lift(Color base) {
    return Color.alphaBlend(
      base.withValues(alpha: 0.72),
      const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.character != character || old.ringColor != ringColor;
}

/// Ang mukha, pero mapipindot — isang pindot at iba na ang mukha.
///
/// Dito nakatira ang pagtanggi sa paghula ng kasarian. Hindi nanghuhula ang
/// app; kapag mali ang napunta kay Jhun, isang pindot lang ang pagpalit at
/// naaalala ito ng regulars book sa susunod na gabi.
class PlayerAvatarButton extends StatelessWidget {
  const PlayerAvatarButton({
    super.key,
    required this.name,
    required this.onCycle,
    this.seed,
    this.size = 36,
    this.ringColor,
    this.tooltip,
  });

  final String name;
  final int? seed;
  final double size;
  final Color? ringColor;
  final VoidCallback? onCycle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final avatar = PlayerAvatar(
      name: name,
      seed: seed,
      size: size,
      ringColor: ringColor,
    );

    if (onCycle == null) return avatar;

    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onCycle,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(SQSpace.xs),
            // Pumipihit kapag nagbago ang mukha. Dito lang, hindi sa
            // PlayerAvatar mismo: sa gumugulong na listahan, ang muling
            // paggamit ng hilera para sa ibang tao ay magpapapihit din
            // nito, at magiging ingay ang sagot sa pindot.
            child: SQFlipSwap(
              swapKey: characterFor(name, seed: seed),
              child: avatar,
            ),
          ),
        ),
      ),
    );
  }
}
