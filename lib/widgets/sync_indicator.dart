import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Ipinapakita lang kapag may hindi pa naipapadalang sulat.
///
/// Sinasadyang **hindi ito alarming**: normal na estado ang offline para sa
/// QM sa court, hindi error. Ang sinasabi nito ay "ligtas ang gabi mo",
/// hindi "may problema".
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key, required this.hasPendingWrites});

  final bool hasPendingWrites;

  @override
  Widget build(BuildContext context) {
    if (!hasPendingWrites) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final sq = context.sq;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sq.surfaceMuted,
        border: Border(bottom: BorderSide(color: sq.line)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SQSpace.lg,
        vertical: SQSpace.md,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: sq.inkMuted),
          const SizedBox(width: SQSpace.md),
          Expanded(
            child: Text(
              l10n.pendingSync,
              style: theme.textTheme.bodySmall?.copyWith(color: sq.inkStrong),
            ),
          ),
        ],
      ),
    );
  }
}
