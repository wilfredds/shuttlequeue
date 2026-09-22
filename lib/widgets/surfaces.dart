/// Ang mga kahon at tatak na paulit-ulit sa buong app.
///
/// Nandito sila para sa isang dahilan: **kapag iba-iba ang kard sa bawat
/// screen, ang app ay mukhang pinagtagpi-tagpi.** Isang [SQCard] lang ang
/// gamit sa dashboard, sa court, sa bill at sa recap — kaya kahit hindi
/// pamilyar ang QM sa isang screen, alam niya kaagad kung ano ang
/// mapipindot at kung ano ang basahin lang.
library;

import 'package:flutter/material.dart';

import '../theme.dart';


/// Ang ibig sabihin ng isang bagay, hindi ang kulay nito.
///
/// Ang tumatawag ay nagsasabi ng *kahulugan* — `SQTone.live` — hindi ng
/// kulay. Kaya kapag nagbago ang palette, isang file lang ang gagalawin.
enum SQTone {
  /// Walang espesyal. Karamihan.
  neutral,

  /// Naglalaro ngayon, o tapos na at tama.
  live,

  /// Kailangan ng pansin: susunod na, may utang, naghihintay nang matagal.
  attention,

  /// Mali, tinanggihan, o hindi pa nakakalaro buong gabi.
  alarm,
}

/// Ang tatlong kulay na kailangan para maipakita ang isang [SQTone].
@immutable
class SQToneColors {
  const SQToneColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

SQToneColors toneColors(BuildContext context, SQTone tone) {
  final sq = context.sq;
  return switch (tone) {
    SQTone.neutral => SQToneColors(
        foreground: sq.inkMuted,
        background: sq.surfaceMuted,
        border: sq.line,
      ),
    SQTone.live => SQToneColors(
        foreground: sq.live,
        background: sq.liveWash,
        border: sq.live.withValues(alpha: 0.28),
      ),
    SQTone.attention => SQToneColors(
        foreground: sq.attention,
        background: sq.attentionWash,
        border: sq.attention.withValues(alpha: 0.28),
      ),
    SQTone.alarm => SQToneColors(
        foreground: sq.alarm,
        background: sq.alarmWash,
        border: sq.alarm.withValues(alpha: 0.28),
      ),
  };
}

/// Isang puting kahon na may hangganan at anino.
///
/// Hindi ito `Card` ng Material dahil kailangan namin ng sariling anino na
/// may offset at lambot — ang `elevation` ng Material 3 ay isang
/// tint na walang tunay na anino, at sa maliwanag na gym ay hindi ito
/// nakikita. May **hangganang 1px** din dito: ang anino lang ay nawawala
/// sa screenshot at sa mga telepono na naka-mataas ang liwanag.
class SQCard extends StatelessWidget {
  const SQCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SQSpace.lg),
    this.tone = SQTone.neutral,
    this.filled = false,
    this.lifted = false,
    this.borderRadius = SQRadius.cardShape,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Ang kahulugan ng kard — kinukulayan ang hangganan, at ang likod kung
  /// [filled].
  final SQTone tone;

  /// Kapag totoo, ang buong likod ay kulay ng [tone]. Para sa mga bagay na
  /// dapat mahanap ng mata nang hindi binabasa.
  final bool filled;

  /// Mas malalim ang anino. Para sa isang bagay lang kada screen — ang
  /// pinakamahalaga.
  final bool lifted;

  final BorderRadius borderRadius;

  /// Panghihimasok kapag talagang kailangan (hal. kulay ng court).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sq = context.sq;
    final tones = toneColors(context, tone);

    return AnimatedContainer(
      duration: context.motion(SQDuration.state),
      curve: SQCurve.enter,
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            (filled ? tones.background : Theme.of(context).colorScheme.surface),
        borderRadius: borderRadius,
        border: Border.all(
          color: tone == SQTone.neutral && !filled ? sq.line : tones.border,
        ),
        boxShadow: lifted ? sq.shadowLifted : sq.shadowSoft,
      ),
      child: child,
    );
  }
}

/// Maliit na tatak: LIVE, ₱ hindi pa bayad, 3 laro.
///
/// Laging may salita. Ang kulay lang ay hindi sapat — may mga QM na hindi
/// nakakakita ng pagkakaiba ng berde at amber, at binabasa ito sa gitna ng
/// maingay na gym.
class SQStatusPill extends StatelessWidget {
  const SQStatusPill({
    super.key,
    required this.label,
    this.tone = SQTone.neutral,
    this.icon,
    this.leading,
    this.dense = false,
  });

  final String label;
  final SQTone tone;
  final IconData? icon;

  /// Kapalit ng icon — para sa tumitibok na tuldok ng live.
  final Widget? leading;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tones = toneColors(context, tone);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? SQSpace.sm : SQSpace.md,
        vertical: dense ? SQSpace.xs : 6,
      ),
      decoration: BoxDecoration(
        color: tones.background,
        borderRadius: SQRadius.pill,
        border: Border.all(color: tones.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SQSpace.xs),
          ] else if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: tones.foreground),
            SizedBox(width: dense ? SQSpace.xs : 5),
          ],
          Text(
            label,
            style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: tones.foreground),
          ),
        ],
      ),
    );
  }
}

/// Pamagat ng isang bahagi, kasama ang pindutan nito kung mayroon.
///
/// Mas malaki ang puwang sa **itaas** kaysa sa ilalim. Ito ang nagsasabi
/// sa mata kung saan nagsisimula ang bagong grupo nang hindi nangangailangan
/// ng linya o kahon.
class SQSectionHeading extends StatelessWidget {
  const SQSectionHeading({
    super.key,
    required this.title,
    this.count,
    this.action,
    this.topSpace = SQSpace.xxl,
  });

  final String title;

  /// Bilang sa tabi ng pamagat — "Pila 12". Hindi ito palamuti: ito ang
  /// pinakamadalas na tanong tungkol sa listahan sa ilalim nito.
  final int? count;

  final Widget? action;
  final double topSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sq = context.sq;

    return Padding(
      padding: EdgeInsets.only(top: topSpace, bottom: SQSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: sq.inkStrong),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: SQSpace.sm),
            Text(
              '$count',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: sq.inkFaint)
                  .tabular,
            ),
          ],
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

/// Isang malaking bilang at ang pangalan nito.
///
/// Ang bilang ay nasa boses ng scoreboard dahil ito ang binabasa nang
/// patingin lang; ang pangalan ay nasa maliit na boses dahil binabasa ito
/// minsan lang.
class SQFigure extends StatelessWidget {
  const SQFigure({
    super.key,
    required this.value,
    required this.label,
    this.tone = SQTone.neutral,
    this.size = 30,
    this.alignment = CrossAxisAlignment.start,
  });

  final String value;
  final String label;
  final SQTone tone;
  final double size;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sq = context.sq;
    final color =
        tone == SQTone.neutral ? sq.ink : toneColors(context, tone).foreground;

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.displaySmall
              ?.copyWith(fontSize: size, color: color)
              .scoreboard,
        ),
        const SizedBox(height: SQSpace.xxs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: sq.inkMuted),
        ),
      ],
    );
  }
}

/// Walang laman — at kung ano ang gagawin tungkol dito.
///
/// Ang walang lamang screen ang **unang** nakikita ng bagong QM. Kaya hindi
/// ito nagsasabi ng "No data"; nagsasabi ito kung ano ang susunod niyang
/// gagawin, at may pindutan para gawin ito kaagad.
class SQEmptyState extends StatelessWidget {
  const SQEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.tone = SQTone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final SQTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sq = context.sq;
    final tones = toneColors(context, tone);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(SQSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tones.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: tones.border),
                ),
                child: Icon(icon, size: 32, color: tones.foreground),
              ),
              const SizedBox(height: SQSpace.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: SQSpace.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: sq.inkMuted),
              ),
              if (action != null) ...[
                const SizedBox(height: SQSpace.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ang bar ng aksyon sa ilalim ng screen.
///
/// Ginagamit kapag ang isang screen ay may aksyon na **hindi "magdagdag"**:
/// magsimula ng laro, magbahagi ng bill. Ang FAB ay para sa pagdagdag lang.
/// Dalawang magkapatong na FAB ang dating nandito, at sa mahabang listahan
/// ay natatakpan nila ang mismong hilera na pinipindot ng QM.
class SQCommandBar extends StatelessWidget {
  const SQCommandBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.sq.lineSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.md,
        SQSpace.lg,
        SQSpace.md,
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Manipis na linya sa pagitan ng mga row sa loob ng isang kard.
///
/// Mas mahina kaysa `Divider` ng Material at may sariling indent, kaya ang
/// listahan ay mukhang isang bagay na may hati — hindi mga hiwalay na
/// piraso.
class SQHairline extends StatelessWidget {
  const SQHairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: context.sq.lineSoft),
    );
  }
}
