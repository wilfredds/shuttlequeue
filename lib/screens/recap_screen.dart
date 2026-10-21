import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../providers/session_providers.dart';
import '../services/night_recap.dart';
import '../theme.dart';
import 'end_session_action.dart';
import '../widgets/motion.dart';
import '../widgets/player_avatar.dart';
import '../widgets/surfaces.dart';

/// Ang buod ng gabi — ang bahaging isc-screenshot ng mga manlalaro.
///
/// Isang tap lang ang kailangan ng QM dito. Bawat numero ay naitala na
/// habang tumatakbo ang gabi; wala siyang dagdag na ie-encode.
///
/// ITO ANG TANGING SCREEN NA NAKIKITA NG IBA. Kaya dito lang may kard na
/// puno ng berde: para kapag nag-screenshot ang isang manlalaro at
/// ipinadala sa grupo, may mukha ang gabi. At kaya rin wala kahit isang
/// tier dito (R-16) — ang "Ben — Beginner" sa group chat ay hindi
/// impormasyon, kahihiyan iyon.
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final session = ref.watch(sessionProvider(sessionId)).value;
    final players =
        ref.watch(playersProvider(sessionId)).value?.data ?? const [];
    final matches = ref.watch(matchesProvider(sessionId)).value ?? const [];

    final recap = buildNightRecap(players: players, matches: matches);

    if (session == null || recap.totalGames == 0) {
      return Scaffold(
        backgroundColor: context.sq.canvas,
        body: SQEmptyState(
          icon: Icons.auto_awesome_outlined,
          title: l10n.recapEmptyTitle,
          body: l10n.recapEmptyBody,
        ),
      );
    }

    final missed = recap.players.where((p) => !p.didPlay).toList();
    final played = recap.players.where((p) => p.didPlay).toList();

    return Scaffold(
      backgroundColor: context.sq.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SQSpace.lg,
          SQSpace.lg,
          SQSpace.lg,
          104,
        ),
        children: [
          _NightSummary(recap: recap),

          // Ang hindi nakalaro ay nasa itaas, hindi nakabaon sa listahan.
          // Ito ang tanging bagay sa screen na kailangang gawan ng aksyon
          // ng QM — at ang gabi ay hindi pa tapos habang nakikita niya ito.
          if (missed.isNotEmpty) ...[
            SQSectionHeading(title: l10n.recapMissedTitle, count: missed.length),
            SQCard(
              tone: SQTone.alarm,
              padding: const EdgeInsets.symmetric(
                horizontal: SQSpace.lg,
                vertical: SQSpace.sm,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < missed.length; i++) ...[
                    if (i > 0) const SQHairline(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SQSpace.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: context.sq.alarm,
                          ),
                          const SizedBox(width: SQSpace.md),
                          Expanded(
                            child: Text(
                              missed[i].name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Isang pindutan lang ang "share" sa screen na ito: ang FAB.
          // Ang dalawang magkaparehong pindutan ay hindi pagpipilian,
          // pag-aalinlangan iyon.
          SQSectionHeading(title: l10n.recapPlayersPlayed(played.length)),
          for (var i = 0; i < played.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: SQSpace.sm),
              child: SQEntrance(
                index: i,
                child: _PlayerCard(
                  recap: played[i],
                  onShare: () => _sharePlayer(context, session, played[i]),
                ),
              ),
            ),
          // ANG PANGALAWANG PASUKAN, at ang mas mahalaga sa dalawa.
          //
          // Dito nakaupo ang QM kapag tapos na ang gabi — binabasa niya ang
          // buod at ipinapadala ito sa group chat. Ang menu sa app bar ang
          // nakasanayang lugar, pero ito ang lugar na TINITINGNAN niya.
          if (session.status != SessionStatus.ended) ...[
            const SizedBox(height: SQSpace.xl),
            SQCard(
              padding: const EdgeInsets.fromLTRB(
                SQSpace.lg,
                SQSpace.lg,
                SQSpace.lg,
                SQSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.courtsEndedTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: SQSpace.xs),
                  Text(
                    l10n.endSessionConfirmBody,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.sq.inkMuted),
                  ),
                  const SizedBox(height: SQSpace.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          confirmEndSession(context, ref, sessionId),
                      icon: const Icon(Icons.flag_outlined, size: 19),
                      label: Text(l10n.endSession),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

/// Ang mukha ng gabi.
///
/// Puno ng berde at may malaking bilang, dahil ito ang bahaging
/// isc-screenshot. Ang tatlong maliliit na bilang sa ilalim ay nasa iisang
/// hanay na may hati — isang bagay na binabasa nang pahalang, hindi
/// tatlong magkakahiwalay na kard.
class _NightSummary extends StatelessWidget {
  const _NightSummary({required this.recap});

  final NightRecap recap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;
    final length = recap.sessionLength;

    return Container(
      padding: const EdgeInsets.all(SQSpace.xl),
      decoration: BoxDecoration(
        color: sq.live,
        borderRadius: SQRadius.heroShape,
        boxShadow: sq.shadowLifted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SQCountUp(
                value: recap.totalGames,
                builder: (context, value) => Text(
                  '${value.round()}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: SQSpace.sm),
              Text(
                l10n.boardGamesLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: SQSpace.xl),
          Row(
            children: [
              _SummaryFact(
                value: '${recap.playersWhoPlayed}',
                label: l10n.recapPlayersLabel,
              ),
              _WhiteDivider(),
              _SummaryFact(
                value: '${recap.totalShuttles}',
                label: l10n.recapShuttlesLabel,
              ),
              if (length != null) ...[
                _WhiteDivider(),
                _SummaryFact(
                  value: '${length.inHours}h ${length.inMinutes.remainder(60)}m',
                  label: l10n.recapOnCourtLabel,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryFact extends StatelessWidget {
  const _SummaryFact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(color: Colors.white)
                .scoreboard,
            maxLines: 1,
          ),
          const SizedBox(height: SQSpace.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WhiteDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: SQSpace.md),
      color: Colors.white.withValues(alpha: 0.2),
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
    final sq = context.sq;

    final facts = <String>[
      l10n.recapPartners(recap.distinctPartners),
      if (recap.mostFrequentPartner != null)
        l10n.recapMostWith(recap.mostFrequentPartner!),
      if (recap.longestWait != null)
        l10n.recapLongestWait(recap.longestWait!.inMinutes),
    ];

    return SQCard(
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.md,
        SQSpace.sm,
        SQSpace.md,
      ),
      child: Row(
        children: [
          PlayerAvatar(
            name: recap.name,
            seed: recap.avatarSeed,
            size: 34,
          ),
          const SizedBox(width: SQSpace.md),
          SizedBox(
            width: 34,
            child: Text(
              '${recap.gamesPlayed}',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: sq.live)
                  .scoreboard,
            ),
          ),
          const SizedBox(width: SQSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recap.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  facts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: sq.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.recapSharePlayer(recap.name),
            icon: Icon(Icons.ios_share, size: 20, color: sq.inkMuted),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}
