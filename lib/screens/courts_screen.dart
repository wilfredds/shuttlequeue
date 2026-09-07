import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../services/matchmaking_service.dart';
import '../widgets/skill_badge.dart';
import '../widgets/sync_indicator.dart';

/// Ang pangunahing screen ng QM habang tumatakbo ang gabi.
///
/// Isang malaking aksyon lang ang nangingibabaw — **Next match** — at
/// nakikita nang sabay-sabay ang mga court at ang pila, walang scroll.
class CourtsScreen extends ConsumerWidget {
  const CourtsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final courtsSynced = ref.watch(courtsProvider(sessionId)).value;
    final playersSynced = ref.watch(playersProvider(sessionId)).value;
    final courts = courtsSynced?.data ?? const [];
    final players = playersSynced?.data ?? const [];
    final pendingWrites = (courtsSynced?.hasPendingWrites ?? false) ||
        (playersSynced?.hasPendingWrites ?? false);
    final liveMatches = ref.watch(liveMatchesProvider(sessionId));
    final queue = ref.watch(queueOrderProvider(sessionId));

    final playersById = {for (final p in players) p.id: p};
    final freeCourt = courts.where((c) => c.isFree).firstOrNull;
    final canStart = freeCourt != null && queue.length >= 4;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SyncIndicator(hasPendingWrites: pendingWrites),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  for (final court in courts)
                    _CourtCard(
                      sessionId: sessionId,
                      court: court,
                      match: liveMatches[court.id],
                      playersById: playersById,
                    ),
                  const SizedBox(height: 20),
                  Text(l10n.upNext, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (queue.isEmpty)
                    Text(
                      l10n.upNextEmpty,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final player in queue.take(12))
                          _QueueChip(player: player),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  // Habang naglo-load pa ang courts, walang laman ang
                  // listahan — at "All courts are playing" ay kasinungalingan
                  // noon. Tahimik muna tayo hanggang may masabi tayong totoo.
                  if (!canStart && courts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        freeCourt == null
                            ? l10n.allCourtsBusy
                            : l10n.needFourPlayers,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.icon(
                      onPressed: canStart
                          ? () => _showSuggestion(context, ref, freeCourt)
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: Text(
                        l10n.nextMatch,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuggestion(
    BuildContext context,
    WidgetRef ref,
    Court court,
  ) async {
    final players =
        ref.read(playersProvider(sessionId)).value?.data ?? const [];
    final history = ref.read(matchesProvider(sessionId)).value ?? const [];

    final suggestion = ref.read(matchmakingServiceProvider).suggestNext(
          players: players,
          now: DateTime.now(),
          history: history,
        );
    if (suggestion == null || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SuggestionSheet(
        sessionId: sessionId,
        court: court,
        suggestion: suggestion,
        allPlayers: players,
      ),
    );
  }
}

class _CourtCard extends ConsumerWidget {
  const _CourtCard({
    required this.sessionId,
    required this.court,
    required this.match,
    required this.playersById,
  });

  final String sessionId;
  final Court court;
  final GameMatch? match;
  final Map<String, SessionPlayer> playersById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isPlaying = match != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isPlaying
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  court.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPlaying
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!isPlaying)
                  Text(
                    l10n.courtFree,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
            if (isPlaying) ...[
              const SizedBox(height: 10),
              _TeamRow(
                sessionId: sessionId,
                match: match!,
                players: match!.teamA
                    .map((id) => playersById[id])
                    .nonNulls
                    .toList(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'vs',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              _TeamRow(
                sessionId: sessionId,
                match: match!,
                players: match!.teamB
                    .map((id) => playersById[id])
                    .nonNulls
                    .toList(),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.substituteHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(matchRepositoryProvider)
                        .cancelMatch(sessionId: sessionId, match: match!),
                    child: Text(l10n.cancelMatch),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _finish(context, ref),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.endMatch),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tapos na ang laro. Walang tanong tungkol sa score — opsyonal iyon at
  /// hindi dapat pumigil sa susunod na laro. Undo ang proteksyon (R-03).
  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(matchRepositoryProvider);
    final finished = match!;

    await repo.endMatch(sessionId: sessionId, match: finished);

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.matchEnded),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () =>
              repo.undoEndMatch(sessionId: sessionId, match: finished),
        ),
      ),
    );
  }
}

/// Isang koponan sa court. Ang bawat pangalan ay napipindot para palitan
/// ang taong iyon nang hindi kinakansela ang buong laro.
class _TeamRow extends ConsumerWidget {
  const _TeamRow({
    required this.sessionId,
    required this.match,
    required this.players,
  });

  final String sessionId;
  final GameMatch match;
  final List<SessionPlayer> players;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final player in players)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => _substitute(context, ref, player),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkillBadge(tier: player.skillTier, size: 22),
                    const SizedBox(width: 5),
                    Text(
                      player.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Pinipili ng QM kung sino ang papasok mula sa pila.
  Future<void> _substitute(
    BuildContext context,
    WidgetRef ref,
    SessionPlayer outgoing,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final queue = ref.read(queueOrderProvider(sessionId));

    if (queue.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.substituteNobody)),
      );
      return;
    }

    final incoming = await showModalBottomSheet<SessionPlayer>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.substituteTitle(outgoing.name),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            // Nasa pagkakasunod-sunod ng pila — kaya ang mungkahi ay
            // ang parehong taong susunod na maglalaro.
            for (final candidate in queue)
              ListTile(
                leading: SkillBadge(tier: candidate.skillTier),
                title: Text(candidate.name),
                subtitle: Text(l10n.gamesPlayedShort(candidate.gamesPlayed)),
                onTap: () => Navigator.of(sheetContext).pop(candidate),
              ),
          ],
        ),
      ),
    );

    if (incoming == null) return;

    await ref.read(matchRepositoryProvider).substitutePlayer(
          sessionId: sessionId,
          match: match,
          outgoingPlayerId: outgoing.id,
          incomingPlayerId: incoming.id,
        );

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.substituteDone(outgoing.name, incoming.name)),
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({required this.player});

  final SessionPlayer player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final waited = DateTime.now().difference(player.waitingSince).inMinutes;

    return Chip(
      avatar: SkillBadge(tier: player.skillTier, size: 22),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(player.name),
          Text(
            '${l10n.gamesPlayedShort(player.gamesPlayed)} · '
            '${l10n.waitingTime(waited < 0 ? 0 : waited)}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

/// Mungkahi ng algorithm — pero **ang QM ang nagpapasya**. Pwedeng palitan
/// ang kahit sino bago simulan.
class _SuggestionSheet extends ConsumerStatefulWidget {
  const _SuggestionSheet({
    required this.sessionId,
    required this.court,
    required this.suggestion,
    required this.allPlayers,
  });

  final String sessionId;
  final Court court;
  final MatchSuggestion suggestion;
  final List<SessionPlayer> allPlayers;

  @override
  ConsumerState<_SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends ConsumerState<_SuggestionSheet> {
  late List<SessionPlayer> _four;
  var _isStarting = false;

  @override
  void initState() {
    super.initState();
    _four = [...widget.suggestion.teamA, ...widget.suggestion.teamB];
  }

  Future<void> _swap(int index) async {
    final chosenIds = _four.map((p) => p.id).toSet();
    final options = queueOrder(widget.allPlayers)
        .where((p) => !chosenIds.contains(p.id))
        .toList();
    if (options.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final picked = await showModalBottomSheet<SessionPlayer>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.swapTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final option in options)
              ListTile(
                leading: SkillBadge(tier: option.skillTier),
                title: Text(option.name),
                subtitle: Text(l10n.gamesPlayedShort(option.gamesPlayed)),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );

    if (picked != null) setState(() => _four[index] = picked);
  }

  Future<void> _start() async {
    setState(() => _isStarting = true);
    final navigator = Navigator.of(context);

    await ref.read(matchRepositoryProvider).startMatch(
          sessionId: widget.sessionId,
          courtId: widget.court.id,
          teamA: [_four[0].id, _four[1].id],
          teamB: [_four[2].id, _four[3].id],
        );

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.suggestionTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),

            // Hindi hinaharangan ang laro — binabalaan lang ang QM (spec §5.4).
            if (widget.suggestion.isMixedSkill)
              _Notice(
                icon: Icons.balance,
                text: l10n.suggestionMixedSkill,
                color: theme.colorScheme.tertiaryContainer,
                onColor: theme.colorScheme.onTertiaryContainer,
              ),
            for (final forced in widget.suggestion.forcedByLongWait)
              _Notice(
                icon: Icons.hourglass_bottom,
                text: l10n.suggestionForcedWait(forced.name),
                color: theme.colorScheme.secondaryContainer,
                onColor: theme.colorScheme.onSecondaryContainer,
              ),

            const SizedBox(height: 4),
            for (var i = 0; i < _four.length; i++) ...[
              if (i == 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('vs', style: theme.textTheme.labelLarge),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SkillBadge(tier: _four[i].skillTier),
                title: Text(_four[i].name),
                subtitle: Text(l10n.gamesPlayedShort(_four[i].gamesPlayed)),
                trailing: TextButton(
                  onPressed: () => _swap(i),
                  child: Text(l10n.swapPlayer),
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isStarting ? null : _start,
                child: Text(l10n.startMatch(widget.court.label)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: onColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}
