/// Ang galaw ng app, nasa isang lugar.
///
/// ISANG PANUNTUNAN ANG SUMASAKLAW DITO: **ang galaw ay sagot, hindi
/// palamuti.** Sa isang gabing apat na oras, ang gumagalaw na walang
/// sinasabi ay nagiging ingay sa ikalawang oras. Kaya bawat isa dito ay may
/// tanong na sinasagot:
///
///  * [SQPressable] — "natamaan ko ba?" Sa gym, hindi mo maririnig ang
///    tap; kailangang makita at maramdaman.
///  * [SQEntrance] — "bago ba ito?" Isang beses lang, sa pagpasok.
///  * [SQLivePulse] — "buhay pa ba?" Ang tanging bagay na paulit-ulit
///    gumagalaw sa app, at isa lang ang kahulugan niya: may laro ngayon.
///  * [SQCountUp] — "gumalaw ba ang bilang?" Kapag tumalon ang numero
///    nang hindi napapansin, may nagagalit sa dulo ng gabi tungkol sa pera.
///
/// Lahat sila ay tumatahimik kapag naka-"reduce motion" ang telepono. Hindi
/// ito pagsunod sa checklist — may tao talagang nahihilo sa gumagalaw na
/// screen, at ang app na ito ay hahawakan nang apat na oras.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';


/// Kumikirot pababa kapag pinindot, at may kaunting yanig.
///
/// Ginagamit sa mga malalaking bagay na mapipindot — kard, court, row ng
/// manlalaro — kung saan hindi sapat ang ripple ng Material dahil natatakpan
/// ng daliri ang kalahati ng bagay.
class SQPressable extends StatefulWidget {
  const SQPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.975,
    this.haptic = HapticLevel.selection,
    this.borderRadius = SQRadius.cardShape,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Gaano kalalim ang pagkirot. Mas malaki ang bagay, mas mababaw dapat.
  final double scale;

  final HapticLevel haptic;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  @override
  State<SQPressable> createState() => _SQPressableState();
}

/// Gaano kalakas ang yanig. Ang mahalagang pindot ay mas malakas.
enum HapticLevel {
  none,

  /// Pagpili, pagbukas — ang karamihan.
  selection,

  /// May nagbago sa gabi: nagsimula ang laro, may nabayaran.
  impact;

  void fire() {
    switch (this) {
      case HapticLevel.none:
        break;
      case HapticLevel.selection:
        HapticFeedback.selectionClick();
      case HapticLevel.impact:
        HapticFeedback.mediumImpact();
    }
  }
}

class _SQPressableState extends State<SQPressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final pressed = _down && enabled;

    return Semantics(
      label: widget.semanticLabel,
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: enabled
            ? () {
                widget.haptic.fire();
                widget.onTap?.call();
              }
            : null,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!.call();
              },
        child: AnimatedScale(
          scale: pressed ? widget.scale : 1,
          duration: context.motion(SQDuration.tap),
          curve: SQCurve.enter,
          // Bukod sa pagkirot, may dumidilim na belo. Kailangan ito: kapag
          // naka-reduce motion, wala nang kirot — at kung ito lang ang
          // palatandaan, ang pindot ay nagmumukhang hindi tumalab.
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: pressed ? 1 : 0,
                    duration: context.motion(SQDuration.tap),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.sq.ink.withValues(alpha: 0.05),
                        borderRadius: widget.borderRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pumapasok mula sa ibaba, isang beses lang, may kaunting pagkakasunod.
///
/// Hindi ito ginagamit sa bawat bagay — sa listahan lang na bagong
/// dumating: ang mga gabi sa dashboard, ang pila, ang bill. Ang layunin ay
/// masabi kung saan nagsisimula at nagtatapos ang listahan habang
/// bumababa ang mata, hindi ang magpasikat.
///
/// Walang `Timer` dito. Isang controller lang na may [Interval] kada
/// item — kaya walang natitirang pending timer sa mga test, at walang
/// nakakalimutang kanselahin kapag mabilis na umalis ang QM.
class SQEntrance extends StatefulWidget {
  const SQEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.rise = 14,
  });

  final Widget child;

  /// Pang-ilan sa listahan. Ang mas malayo ay bahagyang naaantala.
  final int index;

  /// Gaano kataas ang pinanggalingan, sa logical pixels.
  final double rise;

  @override
  State<SQEntrance> createState() => _SQEntranceState();
}

class _SQEntranceState extends State<SQEntrance>
    with SingleTickerProviderStateMixin {
  // Laging ginagawa ang controller, kahit naka-reduce motion — ang haba
  // na lang ang nagiging zero. Kapag ginawa ito nang kondisyonal, ang
  // `dispose()` na ang unang humipo nito at doon pumuputok.
  late final AnimationController _controller;
  late final Animation<double> _curve;

  /// Hanggang ikawalo lang ang inaantala. Kung 24 ang manlalaro, ayaw ng
  /// QM maghintay ng dalawang segundo bago makita ang huli.
  static const int _maxStaggered = 8;

  @override
  void initState() {
    super.initState();
    final step = widget.index.clamp(0, _maxStaggered);
    _controller = AnimationController(
      vsync: this,
      duration: SQDuration.state + Duration(milliseconds: step * 45),
    );
    final start = step == 0 ? 0.0 : (step * 45) / _controller.duration!.inMilliseconds;
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: SQCurve.enter),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.prefersStillness) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        return Opacity(
          opacity: _curve.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _curve.value) * widget.rise),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Ang tanging bagay sa app na tumitibok nang paulit-ulit.
///
/// Isa lang ang kahulugan: **may laro ngayon**. Kung may pangalawang
/// bagay na tumibok, mawawala ang kahulugan ng una.
class SQLivePulse extends StatefulWidget {
  const SQLivePulse({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  State<SQLivePulse> createState() => _SQLivePulseState();
}

class _SQLivePulseState extends State<SQLivePulse>
    with SingleTickerProviderStateMixin {
  // Ginagawa sa initState, HINDI `late final` na may inline na halaga.
  //
  // Ganito ako nadapa dati: `late final _controller = AnimationController(...)`
  // ay ginagawa lang sa UNANG paggamit. Kapag naka-reduce motion, hindi ito
  // nagagalaw ng build() — kaya ang dispose() na ang unang humipo, at doon
  // ito bumubuo ng ticker sa isang patay nang element. Crash sa pag-alis sa
  // dashboard, para lang sa mga taong naka-reduce motion.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: SQDuration.pulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dito ligtas basahin ang MediaQuery. Kapag ayaw ng tao ng galaw,
    // pinapatigil ang ticker mismo — hindi lang itinatago ang epekto.
    if (context.prefersStillness) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    // Nananatili ang tuldok kapag naka-reduce motion — hindi na lang ito
    // kumikislap. Ang impormasyon ay nandiyan pa rin; ang galaw lang ang
    // nawawala.
    if (context.prefersStillness) return core;

    return SizedBox(
      width: widget.size * 2.6,
      height: widget.size * 2.6,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Isang alon na lumalabas at kumukupas, gaya ng radar. Hindi
          // kumukurap ang tuldok mismo: ang kumukurap ay nagmumukhang
          // sira, ang lumalawak ay nagmumukhang buhay.
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.45,
                child: Container(
                  width: widget.size * (1 + t * 1.6),
                  height: widget.size * (1 + t * 1.6),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: core,
      ),
    );
  }
}

/// Pumapasok sa court mula sa sariling panig.
///
/// ANG TANONG NA SINASAGOT: "sino ang nasa court ngayon?" Kapag pinindot ng
/// QM ang Next match, apat na pangalan ang biglang lumilitaw sa isang kard
/// na kanina ay walang laman. Ang biglaang paglitaw ay hindi nagsasabi kung
/// saan sila nanggaling.
///
/// Dito, ang Team A ay pumapasok mula sa kaliwa at ang Team B mula sa kanan
/// — palapit sa net sa gitna, gaya ng tunay na paglakad papasok ng court.
/// Isang beses lang ito, sa pagsisimula ng laro. Ito ang **tanging
/// pinalamutian** na sandali sa app; lahat ng iba ay tahimik, at iyon ang
/// dahilan kung bakit may bigat ito.
///
/// Ilagay ang `key: ValueKey(match.id)` sa magulang para muling tumakbo ito
/// sa bawat bagong laro at hindi sa bawat rebuild.
class SQCourtArrival extends StatefulWidget {
  const SQCourtArrival({
    super.key,
    required this.child,
    required this.fromLeft,
    this.index = 0,
  });

  final Widget child;

  /// Kaliwang panig ng net? Ang Team A ay totoo, ang Team B ay hindi.
  final bool fromLeft;

  /// Pang-ilan sa panig — para hindi sabay na sabay ang dalawa.
  final int index;

  @override
  State<SQCourtArrival> createState() => _SQCourtArrivalState();
}

class _SQCourtArrivalState extends State<SQCourtArrival>
    with SingleTickerProviderStateMixin {
  // Gaya ng iba dito: laging ginagawa ang controller sa initState, kahit
  // naka-reduce motion — ang haba na lang ang nagiging zero. Tingnan ang
  // komento sa SQLivePulse kung bakit.
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SQDuration.page + Duration(milliseconds: widget.index * 70),
    );
    final start = widget.index == 0
        ? 0.0
        : (widget.index * 70) / _controller.duration!.inMilliseconds;
    _curve = CurvedAnimation(
      parent: _controller,
      // `arrive` ang tanging curve na may kaunting tumbok sa dulo. Dito ito
      // nabibigyan ng saysay: may dumating.
      curve: Interval(start, 1, curve: SQCurve.arrive),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.prefersStillness) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          // Mas mabilis kumapit ang opacity kaysa sa posisyon: dumarating
          // ang tao bago pa siya huminto.
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - t) * (widget.fromLeft ? -34 : 34), 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Pumipihit kapag nagbago ang laman.
///
/// ANG TANONG NA SINASAGOT: "tumalab ba ang pindot ko?" Ginawa ito para sa
/// pagpalit ng mukha ng manlalaro sa roster. Kung biglang nagpalit lang ang
/// guhit, ang pagkakaiba ng dalawang mukha ay madaling hindi mapansin — at
/// ang QM ay pipindot ulit, iisipin niyang sira.
///
/// Ang pihit ay hindi palamuti: ito ang nagsasabing **ito pa rin ang
/// parehong tao**, bagong mukha lang. Ang pagkupas lang ay magmumukhang
/// ibang tao ang pumalit.
class SQFlipSwap extends StatelessWidget {
  const SQFlipSwap({super.key, required this.child, required this.swapKey});

  final Widget child;

  /// Kapag nagbago ito, pumipihit. Kapag hindi, walang nangyayari.
  final Object swapKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(SQDuration.state),
      switchInCurve: SQCurve.enter,
      switchOutCurve: SQCurve.exit,
      // Magkapatong ang luma at bago sa kalagitnaan ng pihit, kaya hindi
      // lumulukso ang hilera habang nagpapalit.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey(swapKey);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, inner) {
            // Kalahating pihit kada panig: lumalabas ang luma hanggang
            // gilid, pumapasok ang bago mula sa gilid.
            final t = animation.value;
            final angle = isIncoming ? (1 - t) * 1.5708 : t * -1.5708;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: inner),
            );
          },
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(swapKey), child: child),
    );
  }
}

/// Umaakyat ang bilang papunta sa bagong halaga.
///
/// Para sa pera at sa bilang ng laro. Ang biglang pagpalit ng numero ay
/// hindi nakikita ng mata na nasa ibang bahagi ng screen; ang umaakyat ay
/// nakikita. Sa pera, ito ang pagkakaiba ng "nagbago ba?" at "ano'ng
/// nangyari?" sa dulo ng gabi.
class SQCountUp extends StatelessWidget {
  const SQCountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = SQDuration.count,
  });

  /// Ang bagong halaga. Sa pera, ito ay sentimo — hindi kailanman double.
  final num value;

  /// Tumatanggap ng pansamantalang halaga at nagbabalik ng nakahandang
  /// teksto. Dito nagaganap ang pag-format, kaya ang piso at ang bilang ng
  /// laro ay pareho ang galaw pero magkaiba ang hitsura.
  final Widget Function(BuildContext context, num value) builder;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: context.motion(duration),
      curve: SQCurve.enter,
      builder: (context, animated, _) => builder(context, animated),
    );
  }
}
