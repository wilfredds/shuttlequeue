import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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

    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.pendingSync,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
