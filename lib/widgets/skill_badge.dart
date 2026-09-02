import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';

/// Kulay ng bawat tier. Sinasadyang magkakaiba ang lightness, hindi lang
/// hue — para mabasa pa rin ng may color blindness at sa maliwanag na gym.
Color skillColor(BuildContext context, SkillTier tier) {
  return switch (tier) {
    SkillTier.beginner => const Color(0xFF3B7DD8),
    SkillTier.intermediate => const Color(0xFF1B7F4B),
    SkillTier.advanced => const Color(0xFFB4562A),
  };
}

String skillLabel(AppLocalizations l10n, SkillTier tier) {
  return switch (tier) {
    SkillTier.beginner => l10n.skillBeginner,
    SkillTier.intermediate => l10n.skillIntermediate,
    SkillTier.advanced => l10n.skillAdvanced,
  };
}

/// Isang titik lang: B / I / A.
///
/// R-16: sa harap ng 24 kaklase, mabigat ang salitang "beginner". Ang titik
/// at kulay ay sapat na para sa QM, at hindi nakakahiya para sa manlalaro.
class SkillBadge extends StatelessWidget {
  const SkillBadge({super.key, required this.tier, this.size = 28});

  final SkillTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = skillColor(context, tier);
    final letter = skillLabel(l10n, tier).characters.first.toUpperCase();

    return Tooltip(
      message: skillLabel(l10n, tier),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// Tap para umikot sa tatlong tier. Isang tap kada palit — mas mabilis
/// kaysa dropdown kapag nakatayo at nagmamadali.
class SkillTierSelector extends StatelessWidget {
  const SkillTierSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SkillTier value;
  final ValueChanged<SkillTier>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null
          ? null
          : () {
              final next =
                  SkillTier.values[(value.index + 1) % SkillTier.values.length];
              onChanged!(next);
            },
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SkillBadge(tier: value, size: 32),
      ),
    );
  }
}
