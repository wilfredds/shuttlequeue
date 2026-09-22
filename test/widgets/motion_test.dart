import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/theme.dart';
import 'package:shuttlequeue/widgets/motion.dart';

/// Ang mga pagsubok na ito ay tungkol sa ISANG insidente.
///
/// Isang `AnimationController` na ginawa bilang `late final` na may inline
/// na halaga ay ginagawa lang sa UNANG paggamit. Kapag naka-reduce motion
/// ang telepono, hindi ito nagagalaw ng `build()` — kaya ang `dispose()` na
/// ang unang humipo nito, at doon ito bumubuo ng ticker sa isang patay nang
/// element. Ang resulta ay crash sa pag-alis sa dashboard, para lang sa mga
/// taong naka-reduce motion: ang eksaktong grupong hindi kailanman
/// nasusubukan nang manu-mano.
///
/// Kaya ang bawat isa dito ay ini-pump nang naka-reduce motion AT
/// pagkatapos ay tinatanggal sa puno. Ang pagtanggal ang mahalaga.
Widget _wrap(Widget child, {required bool stillness}) {
  return MaterialApp(
    theme: buildShuttleQueueTheme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: stillness),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('naka-reduce motion: walang pumuputok sa pag-alis', () {
    testWidgets('SQLivePulse', (tester) async {
      await tester.pumpWidget(
        _wrap(const SQLivePulse(color: Colors.green), stillness: true),
      );
      await tester.pump();

      // Ito ang linyang nakakahuli ng bug: inaalis ang widget sa puno.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('SQEntrance', (tester) async {
      await tester.pumpWidget(
        _wrap(const SQEntrance(index: 3, child: Text('Ana')), stillness: true),
      );
      await tester.pump();

      expect(find.text('Ana'), findsOneWidget);
      // Buo kaagad ang opacity: nawawala ang galaw, hindi ang laman.
      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('tumitibok ang pulse kapag pinapayagan ang galaw', (tester) async {
    await tester.pumpWidget(
      _wrap(const SQLivePulse(color: Colors.green), stillness: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Hindi natin sinusukat ang hitsura — sinusukat natin na may umaandar
    // na animasyon, dahil ito ang tanging paulit-ulit na galaw sa app.
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('SQCountUp: nasa huling halaga pa rin kahit walang galaw',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SQCountUp(
          value: 133,
          builder: (context, value) => Text('${value.round()}'),
        ),
        stillness: true,
      ),
    );
    await tester.pump();

    expect(find.text('133'), findsOneWidget);
  });

  testWidgets('SQPressable: tumatawag ang tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        SQPressable(
          haptic: HapticLevel.none,
          onTap: () => taps++,
          child: const SizedBox(width: 120, height: 48, child: Text('Court 1')),
        ),
        stillness: true,
      ),
    );

    await tester.tap(find.text('Court 1'));
    await tester.pump();

    expect(taps, 1);
  });
}
