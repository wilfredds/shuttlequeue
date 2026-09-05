import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/session.dart';
import '../providers/session_providers.dart';
import '../services/night_recap.dart';

/// Ang buod ng gabi — ang bahaging isc-screenshot ng mga manlalaro.
///
/// Isang tap lang ang kailangan ng QM dito. Bawat numero ay naitala na
/// habang tumatakbo ang gabi; wala siyang dagdag na ie-encode.
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final session = ref.watch(sessionProvider(sessionId)).value;
    final players =
        ref.watch(playersProvider(sessionId)).value?.data ?? const [];
    final matches = ref.watch(matchesProvider(sessionId)).value ?? const [];

    final recap = buildNightRecap(players: players, matches: matches);

    if (session == null || recap.totalGames == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 72,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(l10n.recapEmptyTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                l10n.recapEmptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _NightSummary(recap: recap),
          const SizedBox(height: 12),
          for (final player in recap.players)
            _PlayerCard(
              recap: player,
              onShare: () => _sharePlayer(context, session, player),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _shareNight(context, session, recap),
        icon: const Icon(Icons.share_outlined),
        label: Text(l10n.recapShareAll),
      ),
    );
  }

  /// Ang buong gabi bilang plain text, handa nang i-paste sa group chat.
  ///
  /// Pansinin: walang skill tier dito at walang ranking (R-16). Nakaayos
  /// ayon sa pangalan, gaya ng ginagawa ng service mismo.
  Future<void> _shareNight(
    BuildContext context,
    Session session,
    NightRecap recap,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final buffer = StringBuffer()
      ..writeln(session.title)
      ..writeln();

    for (final player in recap.players) {
      if (!player.didPlay) continue;
      final bits = <String>[l10n.recapGamesLabel(player.gamesPlayed)];
      if (player.distinctPartners > 0) {
        bits.add(l10n.recapPartners(player.distinctPartners));
      }
      buffer.writeln('${player.name} — ${bits.join(' · ')}');
    }

    buffer
      ..writeln()
      ..writeln(
        '${l10n.recapTotalGames(recap.totalGames)} · '
        '${l10n.recapPlayersPlayed(recap.playersWhoPlayed)} · '
        '${l10n.recapTotalShuttles(recap.totalShuttles)}',
      );

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: session.title),
    );
  }

  Future<void> _sharePlayer(
    BuildContext context,
    Session session,
    PlayerRecap player,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final lines = <String>[
      '${player.name} — ${session.title}',
      '',
      l10n.recapGamesLabel(player.gamesPlayed),
      l10n.recapPartners(player.distinctPartners),
      l10n.recapOpponents(player.distinctOpponents),
    ];

    if (player.mostFrequentPartner != null) {
      lines.add(l10n.recapMostWith(player.mostFrequentPartner!));
    }
    if (player.longestWait != null) {
      lines.add(l10n.recapLongestWait(player.longestWait!.inMinutes));
    }
    if (player.shuttlesUsed > 0) {
      lines.add(l10n.recapTotalShuttles(player.shuttlesUsed));
    }

    await SharePlus.instance.share(
      ShareParams(text: lines.join('\n'), subject: player.name),
    );
  }
}

class _NightSummary extends StatelessWidget {
  const _NightSummary({required this.recap});

  final NightRecap recap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final length = recap.sessionLength;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recapNightSummary,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.recapTotalGames(recap.totalGames),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                l10n.recapPlayersPlayed(recap.playersWhoPlayed),
                l10n.recapTotalShuttles(recap.totalShuttles),
                if (length != null)
                  l10n.recapDuration(
                    length.inHours,
                    length.inMinutes.remainder(60),
                  ),
              ].join(' · '),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.recap, required this.onShare});

  final PlayerRecap recap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Ang hindi nakalaro ay ipinapakita pa rin — mahalagang makita ng QM
    // kung may naiwan, at ito mismo ang senyales na may mali sa gabi.
    if (!recap.didPlay) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(recap.name),
          subtitle: Text(
            l10n.recapDidNotPlay,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      );
    }

    final facts = <String>[
      l10n.recapPartners(recap.distinctPartners),
      if (recap.mostFrequentPartner != null)
        l10n.recapMostWith(recap.mostFrequentPartner!),
      if (recap.longestWait != null)
        l10n.recapLongestWait(recap.longestWait!.inMinutes),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          recap.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.recapGamesLabel(recap.gamesPlayed),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facts.join(' · '),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.recapSharePlayer(recap.name),
              icon: const Icon(Icons.ios_share, size: 20),
              onPressed: onShare,
            ),
          ],
        ),
      ),
    );
  }
}
