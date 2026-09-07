import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ang marka ng ShuttleQueue, iginuguhit sa canvas.
///
/// Pareho ito ng hugis sa favicon at sa home-screen icon — nakasulat ang
/// sukat sa `tool/generate_icons.py`. Iisang guhit sa dalawang lugar, kaya
/// hindi sila maghihiwalay kapag inayos ang isa.
///
/// Hindi Material icon: `Icons.sports_tennis` ang dati, at raketa iyon ng
/// tennis — nasa bawat app iyon. Sariling marka ang kailangan ng app na
/// ilalagay sa portfolio.
class ShuttleMark extends StatelessWidget {
  const ShuttleMark({super.key, this.size = 64, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: size,
      // Dekorasyon ang marka; ang pangalan ng app ay nasa tabi nito bilang
      // tunay na teksto, kaya walang dapat basahin dito ang screen reader.
      child: ExcludeSemantics(
        child: CustomPaint(painter: _ShuttlePainter(paintColor)),
      ),
    );
  }
}

class _ShuttlePainter extends CustomPainter {
  const _ShuttlePainter(this.color);

  final Color color;

  /// Ang hugis sa unit coordinates (0..1), bago ang anumang pag-fit.
  static Path _shape() {
    final path = Path()
      // Ang tapon (cork).
      ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.755), radius: 0.158));

    // Tatlong balahibo: magkadikit sa ibaba (isang leeg), may makikitid na
    // hiwa sa itaas. Mas malapad kaysa mataas — iyon ang tunay na sukat.
    const yBot = 0.640;
    const yTop = 0.280;

    for (final t in const [-1.0, 0.0, 1.0]) {
      final bx = 0.5 + t * 0.052;
      final tx = 0.5 + t * 0.238;
      path
        ..moveTo(bx - 0.052, yBot)
        ..lineTo(bx + 0.052, yBot)
        ..lineTo(tx + 0.096, yTop)
        ..lineTo(tx - 0.096, yTop)
        ..close();
    }

    // Bahagyang tagilid — parang lumilipad, hindi nakapatong.
    return path.transform(
      (Matrix4.identity()
            ..translateByDouble(0.5, 0.62, 0, 1)
            ..rotateZ(-10 * math.pi / 180)
            ..translateByDouble(-0.5, -0.62, 0, 1))
          .storage,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape();

    // Pinupuno ang buong kahon. Kung hindi, ang marka ay kumakain lang ng
    // mga dalawang-katlo ng espasyo nito at mukhang maliit at bansot sa
    // tabi ng pangalan ng app — na siyang unang nangyari.
    //
    // Sinusukat natin ang tunay na hangganan pagkatapos ng pag-ikot, kaya
    // hindi ito nasisira kapag inayos ang anggulo.
    final bounds = shape.getBounds();
    final scale = math.min(
      size.width / bounds.width,
      size.height / bounds.height,
    );

    canvas.save();
    canvas.translate(
      (size.width - bounds.width * scale) / 2 - bounds.left * scale,
      (size.height - bounds.height * scale) / 2 - bounds.top * scale,
    );
    canvas.scale(scale);
    canvas.drawPath(
      shape,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShuttlePainter oldDelegate) => oldDelegate.color != color;
}
