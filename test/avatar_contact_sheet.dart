// Pansamantalang kasangkapan: nagguguhit ng contact sheet ng mga mukha para
// matingnan sila ng mata, hindi lang ng test. Tatakbo nang:
//
//   flutter test test/avatar_contact_sheet.dart
//
// Hindi nagtatapos sa _test.dart kaya hindi ito kasama sa `flutter test`.
//
// Hindi dumadaan sa widget tree: ang painter ang tinatawag nang direkta sa
// isang PictureRecorder. Walang pumpAndSettle na pwedeng mag-hang, walang
// surface size, walang font na kailangang i-load.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/widgets/player_avatar.dart';

const _roster = [
  'Maricel', 'Jhun', 'Bea', 'Rico', 'Neneng', 'Dondon',
  'Aileen', 'Bing', 'Jomar', 'Shiela', 'Tope', 'Evelyn',
  'Kuya Jun', 'Ate Vi', 'Paeng', 'Lorna', 'Benjie', 'Cherry',
];

const _tierColors = [
  Color(0xFF3B7DD8),
  Color(0xFF1B7F4B),
  Color(0xFFB4562A),
];

void main() {
  test('contact sheet', () async {
    final out = Platform.environment['SQ_SHEET'] ?? 'avatar_sheet.png';

    const w = 1040.0;
    const h = 900.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFF5F8F5),
    );

    /// Isang mukha sa (x, y) na may sukat na [size].
    void face(
      double x,
      double y,
      double size, {
      required String name,
      int? seed,
      Color? ring,
    }) {
      canvas.save();
      canvas.translate(x, y);
      paintPlayerCharacter(
        canvas: canvas,
        size: size,
        name: name,
        seed: seed,
        ringColor: ring,
      );
      canvas.restore();
    }

    var y = 24.0;

    // Hanay 1-3: ang totoong roster sa tatlong sukat na ginagamit sa app.
    for (final size in const [26.0, 34.0, 64.0]) {
      var x = 24.0;
      for (final name in _roster) {
        face(x, y, size, name: name);
        x += size + 10;
      }
      y += size + 22;
    }

    // Hanay 4-5: tatlumpu't anim na magkasunod na buto. Dito nakikita kung
    // talagang magkakaiba ang walong anyo ng buhok at ang isinusuot.
    for (var row = 0; row < 2; row++) {
      var x = 24.0;
      for (var i = 0; i < 18; i++) {
        face(x, y, 52, name: 'x', seed: row * 18 + i);
        x += 56;
      }
      y += 74;
    }

    // Hanay 6: may singsing ng skill tier.
    var x = 24.0;
    for (final ring in _tierColors) {
      for (final name in const ['Maricel', 'Jhun', 'Bea']) {
        face(x, y, 46, name: name, ring: ring);
        x += 54;
      }
      x += 16;
    }
    y += 68;

    // Hanay 7: sa madilim na board sa dingding.
    canvas.drawRect(
      Rect.fromLTWH(0, y - 10, w, 72),
      Paint()..color = const Color(0xFF0C1410),
    );
    x = 24.0;
    for (final name in const ['Maricel', 'Jhun', 'Bea', 'Rico', 'Neneng']) {
      face(x, y, 48, name: name);
      x += 58;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(out).writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote $out (${bytes.lengthInBytes} bytes)');
  });
}
