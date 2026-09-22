/// Ang buong hitsura ng ShuttleQueue, nasa isang file.
///
/// ANG EKSENA, HINDI ANG KATEGORYA. Hindi ito ginawa para sa maaliwalas na
/// desktop. Ginawa ito para sa isang taong **nakatayo sa gym**: maliwanag
/// ang fluorescent, isang kamay lang ang libre, ang isa ay hawak ang
/// clipboard o shuttle, at may nagtatanong sa kanya kung kailan ito
/// makakalaro. Kaya:
///
///  * **Maliwanag ang app.** Sa ilalim ng gym lights, ang madilim na screen
///    ay salamin. Ang board sa TV lang ang madilim (tingnan
///    `board_screen.dart`) — malayo yun at nakaharap sa lahat.
///  * **Dalawa ang boses.** `Inter` para sa binabasang malapitan — may
///    `tnum` kaya hindi tumatalon ang hanay ng pera habang nagbabago. Ang
///    `Archivo` (wdth 88) ay para sa mga bilang na binabasa mula sa malayo:
///    numero ng court, bilang ng laro, kabuuang bayad.
///  * **Hindi random ang kulay.** Bawat kulay dito ay may trabaho. Kapag
///    naghanap ka ng pang-dekorasyon lang, wala.
///
/// Ang mga token ay nasa [SQTokens], nakakabit sa `ThemeData` bilang
/// extension, at nakukuha sa `context.sq`. Kaya kahit ang board na may
/// sarili nitong madilim na `Theme` ay may tamang kulay pa rin.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Ang berde ng court. Ito ang nauna pa sa akin sa app na ito at hindi
/// dapat magbago — ito na ang mukha ng ShuttleQueue sa logo at sa icon.
const Color _courtGreen = Color(0xFF1B5E20);
const Color _courtGreenBright = Color(0xFF2E7D32);
const Color _courtGreenDeep = Color(0xFF0C3B10);
const Color _courtGreenWash = Color(0xFFDCEBDD);

/// Mga neutral na may bahid ng berde. Ang purong gray sa tabi ng berde ay
/// mukhang maruming asul; ang bahagyang binahiran ay nagiging isang mundo.
const Color _ink = Color(0xFF0D1A11);
const Color _inkStrong = Color(0xFF23342A);
const Color _inkMuted = Color(0xFF55675C);
const Color _inkFaint = Color(0xFF8798A0);
const Color _line = Color(0xFFDDE4DE);
const Color _lineSoft = Color(0xFFEDF1ED);
const Color _canvas = Color(0xFFF5F8F5);
const Color _surface = Color(0xFFFFFFFF);
const Color _surfaceMuted = Color(0xFFF0F4F0);

/// Ang susunod na tatawagin — ang kulay na hinahanap ng mata sa isang
/// listahan. Amber dahil ito lang ang kulay na hindi berde at hindi pula
/// sa buong app, kaya walang ibang bagay ang kaagaw nito sa pansin.
const Color _attention = Color(0xFFB45309);
const Color _attentionWash = Color(0xFFFDF0D5);

/// Mali, tinanggihan, o hindi pa nakakalaro.
const Color _alarm = Color(0xFFB42318);
const Color _alarmWash = Color(0xFFFDECEA);

// ---------------------------------------------------------------------------
// Mga sukat
// ---------------------------------------------------------------------------

/// Isang sukatan lang ng espasyo sa buong app.
///
/// Apat ang batayan. Ang lahat ng padding at gap ay galing dito, kaya ang
/// ritmo ng bawat screen ay pareho kahit magkaibang tao ang sumulat nito.
abstract final class SQSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double huge = 40;
}

abstract final class SQRadius {
  static const Radius chip = Radius.circular(999);
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double sheet = 28;

  static const BorderRadius cardShape = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius heroShape = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pill = BorderRadius.all(chip);
}

/// Gaano katagal gumagalaw ang mga bagay.
///
/// Hindi nakakalat ang mga numero sa mga screen: ang gumagalaw nang 180ms
/// at ang gumagalaw nang 200ms ay mukhang **sira**, hindi magkaiba.
abstract final class SQDuration {
  /// Sagot sa daliri. Anumang mas matagal pa dito ay parang na-lag.
  static const Duration tap = Duration(milliseconds: 110);

  /// Karaniwang pagbabago ng estado: lumitaw, nawala, nagpalit ng kulay.
  static const Duration state = Duration(milliseconds: 220);

  /// Paglipat ng screen, pagbukas ng sheet.
  static const Duration page = Duration(milliseconds: 320);

  /// Ang bilang na umaakyat kapag may natapos na laro.
  static const Duration count = Duration(milliseconds: 620);

  /// Isang tibok ng "live". Mabagal — hindi ito alarma, palatandaan lang.
  static const Duration pulse = Duration(milliseconds: 1900);
}

abstract final class SQCurve {
  /// Mabilis sa umpisa, dahan-dahan sa dulo. Ito ang halos lahat.
  static const Curve enter = Cubic(0.2, 0, 0, 1);

  /// Pag-alis: mabilis tumakas, walang pabalik-balik.
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// May kaunting tumbok sa dulo — para sa mga bagay na *dumarating*.
  static const Curve arrive = Cubic(0.16, 1.12, 0.3, 1);
}

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

/// Ang mga kulay at anino na walang katumbas sa `ColorScheme`.
///
/// Sinadya kong hindi pilitin sa `ColorScheme` ang mga ito. Ang `tertiary`
/// ay hindi nagsasabi kung ano ang trabaho niya; ang `attention` ay
/// nagsasabi. Kapag may nagbasa nito makalipas ang anim na buwan, dapat
/// malaman niya kung kailan gagamitin ang bawat isa nang hindi nagtatanong.
@immutable
class SQTokens extends ThemeExtension<SQTokens> {
  const SQTokens({
    required this.canvas,
    required this.surfaceMuted,
    required this.ink,
    required this.inkStrong,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.lineSoft,
    required this.live,
    required this.liveWash,
    required this.attention,
    required this.attentionWash,
    required this.alarm,
    required this.alarmWash,
    required this.shadowSoft,
    required this.shadowLifted,
    required this.shadowFloating,
  });

  /// Likod ng screen. Hindi puti — para lumutang ang mga puting kard.
  final Color canvas;

  /// Kahon sa loob ng kard: input, listahan, hindi pa punong slot.
  final Color surfaceMuted;

  final Color ink;
  final Color inkStrong;
  final Color inkMuted;
  final Color inkFaint;
  final Color line;
  final Color lineSoft;

  /// Naglalaro ngayon.
  final Color live;
  final Color liveWash;

  /// Susunod na tatawagin, o may utang pa.
  final Color attention;
  final Color attentionWash;

  /// Hindi pa nakakalaro, tinanggihan, o mapanganib na pindutin.
  final Color alarm;
  final Color alarmWash;

  /// Nakadikit pa rin sa papel — para sa mga kard sa listahan.
  final List<BoxShadow> shadowSoft;

  /// Nakaangat — ang kard ng gabing ito, ang court na may laro.
  final List<BoxShadow> shadowLifted;

  /// Nakalutang sa ibabaw ng lahat — sheet, menu, FAB.
  final List<BoxShadow> shadowFloating;

  @override
  SQTokens copyWith({
    Color? canvas,
    Color? surfaceMuted,
    Color? ink,
    Color? inkStrong,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
    Color? lineSoft,
    Color? live,
    Color? liveWash,
    Color? attention,
    Color? attentionWash,
    Color? alarm,
    Color? alarmWash,
    List<BoxShadow>? shadowSoft,
    List<BoxShadow>? shadowLifted,
    List<BoxShadow>? shadowFloating,
  }) {
    return SQTokens(
      canvas: canvas ?? this.canvas,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      inkStrong: inkStrong ?? this.inkStrong,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      live: live ?? this.live,
      liveWash: liveWash ?? this.liveWash,
      attention: attention ?? this.attention,
      attentionWash: attentionWash ?? this.attentionWash,
      alarm: alarm ?? this.alarm,
      alarmWash: alarmWash ?? this.alarmWash,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowLifted: shadowLifted ?? this.shadowLifted,
      shadowFloating: shadowFloating ?? this.shadowFloating,
    );
  }

  @override
  SQTokens lerp(covariant SQTokens? other, double t) {
    if (other == null) return this;
    return SQTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkStrong: Color.lerp(inkStrong, other.inkStrong, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t)!,
      live: Color.lerp(live, other.live, t)!,
      liveWash: Color.lerp(liveWash, other.liveWash, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      attentionWash: Color.lerp(attentionWash, other.attentionWash, t)!,
      alarm: Color.lerp(alarm, other.alarm, t)!,
      alarmWash: Color.lerp(alarmWash, other.alarmWash, t)!,
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t)!,
      shadowLifted: BoxShadow.lerpList(shadowLifted, other.shadowLifted, t)!,
      shadowFloating:
          BoxShadow.lerpList(shadowFloating, other.shadowFloating, t)!,
    );
  }
}

/// `context.sq.attention` sa halip na paulit-ulit na `Theme.of(context)`.
extension SQThemeAccess on BuildContext {
  SQTokens get sq =>
      Theme.of(this).extension<SQTokens>() ?? _lightTokens;

  /// Kapag naka-"reduce motion" ang telepono, ibinabalik nito ang zero.
  ///
  /// May dahilan itong nandito at hindi na lang nakakalat: **minsan na
  /// akong nakasira ng app dahil dito.** Ang `AnimationController` na
  /// ginawa sa `build` ay hindi naabot kapag hindi gumagalaw ang UI, kaya
  /// pumutok ang `dispose`. Ang tamang gamit: laging gawin ang controller,
  /// ang haba na lang ang gawing zero.
  Duration motion(Duration full) {
    return MediaQuery.maybeDisableAnimationsOf(this) ?? false
        ? Duration.zero
        : full;
  }

  /// Totoo kapag dapat tahimik ang screen: ayaw ng may-ari ng galaw.
  bool get prefersStillness =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

const SQTokens _lightTokens = SQTokens(
  canvas: _canvas,
  surfaceMuted: _surfaceMuted,
  ink: _ink,
  inkStrong: _inkStrong,
  inkMuted: _inkMuted,
  inkFaint: _inkFaint,
  line: _line,
  lineSoft: _lineSoft,
  live: _courtGreen,
  liveWash: _courtGreenWash,
  attention: _attention,
  attentionWash: _attentionWash,
  alarm: _alarm,
  alarmWash: _alarmWash,
  // May offset at may lambot ang bawat anino. Ang anino na walang offset ay
  // hindi anino — palamuti yun.
  shadowSoft: [
    BoxShadow(
      color: Color(0x0F0D1A11),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A0D1A11),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ],
  shadowLifted: [
    BoxShadow(
      color: Color(0x140D1A11),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x140D1A11),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ],
  shadowFloating: [
    BoxShadow(
      color: Color(0x1A0D1A11),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1F0D1A11),
      blurRadius: 40,
      offset: Offset(0, 18),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

/// Pantay ang lapad ng bawat numero.
///
/// Kailangan ito kahit saan may nagbabagong bilang: pera, oras ng
/// paghihintay, bilang ng laro. Kung wala, gumagalaw pakaliwa-pakanan ang
/// buong hanay tuwing 9 papuntang 10 — at mukhang sira ang app.
const List<FontFeature> _tabular = [
  FontFeature.tabularFigures(),
  FontFeature.slashedZero(),
];

/// Ang boses na binabasa mula sa malayo.
const String kDisplayFamily = 'Archivo';

/// Ang boses na binabasa sa kamay.
const String kTextFamily = 'Inter';

extension SQTextStyle on TextStyle {
  /// Para sa mga numerong nagbabago habang nakatingin ang QM.
  TextStyle get tabular => copyWith(fontFeatures: _tabular);

  /// Ang boses ng scoreboard, para sa mga bilang na dapat mabasa sa malayo.
  TextStyle get scoreboard => copyWith(
        fontFamily: kDisplayFamily,
        fontWeight: FontWeight.w800,
        fontFeatures: _tabular,
      );
}

TextTheme _buildTextTheme() {
  // Ang display ay Archivo: bahagyang makitid, kaya kasya ang "₱1,200.00"
  // sa isang linya kahit sa 360px na telepono.
  TextStyle display(double size, {double height = 1.02, double track = -0.5}) {
    return TextStyle(
      fontFamily: kDisplayFamily,
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: height,
      letterSpacing: track,
      color: _ink,
      fontFeatures: _tabular,
    );
  }

  TextStyle text(
    double size,
    FontWeight weight, {
    double height = 1.42,
    double track = 0,
    Color color = _ink,
  }) {
    return TextStyle(
      fontFamily: kTextFamily,
      fontWeight: weight,
      fontSize: size,
      height: height,
      letterSpacing: track,
      color: color,
    );
  }

  return TextTheme(
    displayLarge: display(46, track: -1.4),
    displayMedium: display(36, track: -1),
    displaySmall: display(28, track: -0.6),
    // Ang headline ay Archivo pa rin pero 600 — pamagat ng screen, hindi
    // bilang. Sapat ang bigat para maging pinuno ng pahina.
    headlineLarge: display(26, height: 1.1, track: -0.4)
        .copyWith(fontWeight: FontWeight.w600),
    headlineMedium: display(22, height: 1.15, track: -0.3)
        .copyWith(fontWeight: FontWeight.w600),
    headlineSmall: display(19, height: 1.2, track: -0.2)
        .copyWith(fontWeight: FontWeight.w600),
    titleLarge: text(19, FontWeight.w600, height: 1.25, track: -0.2),
    titleMedium: text(16, FontWeight.w600, height: 1.3, track: -0.1),
    titleSmall: text(14, FontWeight.w600, height: 1.3),
    bodyLarge: text(16, FontWeight.w400, color: _inkStrong),
    bodyMedium: text(14.5, FontWeight.w400, color: _inkStrong),
    bodySmall: text(13, FontWeight.w400, height: 1.4, color: _inkMuted),
    labelLarge: text(16, FontWeight.w600, height: 1.2, track: 0.1),
    labelMedium: text(13, FontWeight.w600, height: 1.2, track: 0.2),
    // Ang pinakamaliit ay may puwang sa pagitan ng titik — ang maliit at
    // masikip ay hindi mabasa sa ilalim ng ilaw ng gym.
    labelSmall: text(11.5, FontWeight.w600, height: 1.2, track: 0.6),
  );
}

// ---------------------------------------------------------------------------
// Paglipat ng screen
// ---------------------------------------------------------------------------

/// Isang paglipat lang sa buong app: umuusad pasulong ang bagong screen
/// habang bahagyang umuurong ang naiwan.
///
/// Hindi ito pang-porma. Sinasabi nito kung saan ka nanggaling, kaya kahit
/// hindi tumitingin sa itaas ang QM, alam niyang may binuksan siya at
/// alam niyang may babalikan.
class SQPageTransitions extends PageTransitionsBuilder {
  const SQPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.prefersStillness) return child;

    final enter = CurvedAnimation(
      parent: animation,
      curve: SQCurve.enter,
      reverseCurve: SQCurve.exit,
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: SQCurve.enter,
      reverseCurve: SQCurve.exit,
    );

    return AnimatedBuilder(
      animation: leave,
      builder: (context, inner) {
        // Ang naiwang screen ay lumalayo nang kaunti at kumukupas — hindi
        // lumilipad palabas. Nananatili siyang kita sa likod, kaya ramdam
        // na nakapatong lang ang bago.
        return Transform.scale(
          scale: 1 - (leave.value * 0.035),
          child: Opacity(opacity: 1 - (leave.value * 0.35), child: inner),
        );
      },
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ang theme
// ---------------------------------------------------------------------------

/// Isang pinagmumulan ng hitsura ng app.
///
/// Ginagamit din ito ng screenshot generator sa `tool/screenshots/`, kaya
/// ang ipinapakita sa anunsyo ay siya ring nakikita ng QM. Kapag may
/// binago dito, nagbabago rin ang mga larawan sa Facebook.
ThemeData buildShuttleQueueTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _courtGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: _courtGreen,
    onPrimary: Colors.white,
    primaryContainer: _courtGreenWash,
    onPrimaryContainer: _courtGreenDeep,
    secondary: _attention,
    onSecondary: Colors.white,
    secondaryContainer: _attentionWash,
    onSecondaryContainer: const Color(0xFF6B3005),
    tertiary: _courtGreenBright,
    error: _alarm,
    onError: Colors.white,
    errorContainer: _alarmWash,
    onErrorContainer: const Color(0xFF6B120B),
    surface: _surface,
    onSurface: _ink,
    onSurfaceVariant: _inkMuted,
    outline: _line,
    outlineVariant: _lineSoft,
    surfaceContainerLowest: _surface,
    surfaceContainerLow: _canvas,
    surfaceContainer: _surfaceMuted,
    surfaceContainerHigh: const Color(0xFFE8EEE8),
    surfaceContainerHighest: const Color(0xFFE1E8E2),
  );

  final textTheme = _buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _canvas,
    fontFamily: kTextFamily,
    textTheme: textTheme,
    // 56dp ang pinakamababa sa mga pangunahing pindutan — madaling tamaan
    // kahit nagmamadali at isang kamay lang ang libre.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    extensions: const [_lightTokens],

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SQPageTransitions(),
        TargetPlatform.iOS: SQPageTransitions(),
        TargetPlatform.macOS: SQPageTransitions(),
        TargetPlatform.windows: SQPageTransitions(),
        TargetPlatform.linux: SQPageTransitions(),
        TargetPlatform.fuchsia: SQPageTransitions(),
      },
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: _canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: SQSpace.lg,
      titleTextStyle: textTheme.headlineSmall,
      iconTheme: const IconThemeData(color: _inkStrong, size: 24),
    ),

    cardTheme: CardThemeData(
      color: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: SQRadius.cardShape),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: SQSpace.xl),
        shape: const RoundedRectangleBorder(borderRadius: SQRadius.cardShape),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 17),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: SQSpace.lg),
        side: const BorderSide(color: _line, width: 1.5),
        foregroundColor: _inkStrong,
        shape: const RoundedRectangleBorder(borderRadius: SQRadius.cardShape),
        textStyle: textTheme.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: _courtGreen,
        padding: const EdgeInsets.symmetric(horizontal: SQSpace.md),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SQRadius.md)),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: _inkStrong,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _courtGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        color: Colors.white,
        fontSize: 17,
      ),
      shape: const RoundedRectangleBorder(borderRadius: SQRadius.heroShape),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SQSpace.lg,
        vertical: SQSpace.lg,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(color: _inkFaint),
      labelStyle: textTheme.bodyMedium?.copyWith(color: _inkMuted),
      floatingLabelStyle: textTheme.labelMedium?.copyWith(color: _courtGreen),
      border: const OutlineInputBorder(
        borderRadius: SQRadius.cardShape,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: SQRadius.cardShape,
        borderSide: BorderSide(color: _line),
      ),
      // Makapal ang border kapag naka-focus: ito ang tanging paraan para
      // malaman ng gumagamit ng keyboard kung nasaan siya.
      focusedBorder: const OutlineInputBorder(
        borderRadius: SQRadius.cardShape,
        borderSide: BorderSide(color: _courtGreen, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: SQRadius.cardShape,
        borderSide: BorderSide(color: _alarm, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: SQRadius.cardShape,
        borderSide: BorderSide(color: _alarm, width: 2),
      ),
      errorStyle: textTheme.bodySmall?.copyWith(color: _alarm),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _surfaceMuted,
      side: const BorderSide(color: _line),
      labelStyle: textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(
        horizontal: SQSpace.md,
        vertical: SQSpace.sm,
      ),
      shape: const RoundedRectangleBorder(borderRadius: SQRadius.pill),
      showCheckmark: false,
    ),

    listTileTheme: ListTileThemeData(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: SQSpace.lg),
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall,
      iconColor: _inkMuted,
      shape: const RoundedRectangleBorder(borderRadius: SQRadius.cardShape),
    ),

    dividerTheme: const DividerThemeData(
      color: _lineSoft,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _inkStrong,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: const Color(0xFF9FD8A6),
      elevation: 6,
      insetPadding: const EdgeInsets.all(SQSpace.md),
      shape: const RoundedRectangleBorder(borderRadius: SQRadius.cardShape),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyLarge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(SQRadius.xl)),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: _line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SQRadius.sheet),
        ),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: _courtGreen,
      unselectedLabelColor: _inkMuted,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: _lineSoft,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: _inkStrong,
        borderRadius: const BorderRadius.all(Radius.circular(SQRadius.sm)),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(
        horizontal: SQSpace.md,
        vertical: SQSpace.sm,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _courtGreen,
      linearTrackColor: _surfaceMuted,
      circularTrackColor: _surfaceMuted,
      linearMinHeight: 6,
    ),

    // Ang mga bagay na hindi natin iginuhit ay may sariling default na
    // hindi kabilang sa anumang disenyo. Ito ang pinakamurang palatandaan
    // na ginawa — hindi binuo — ang app.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: _courtGreen,
      selectionColor: _courtGreen.withValues(alpha: 0.22),
      selectionHandleColor: _courtGreen,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(_inkFaint.withValues(alpha: 0.5)),
      radius: const Radius.circular(SQRadius.sm),
      thickness: const WidgetStatePropertyAll(6),
      crossAxisMargin: 2,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0xFFFFFFFF),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _courtGreen
            : _line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _courtGreen
            : Colors.transparent,
      ),
      side: const BorderSide(color: _inkFaint, width: 1.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: _surfaceMuted,
        foregroundColor: _inkMuted,
        selectedBackgroundColor: _courtGreenWash,
        selectedForegroundColor: _courtGreenDeep,
        side: const BorderSide(color: _line),
        textStyle: textTheme.labelMedium,
      ),
    ),
  );
}
