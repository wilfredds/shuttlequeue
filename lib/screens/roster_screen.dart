import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../repositories/player_repository.dart';
import '../widgets/skill_badge.dart';
import '../widgets/sync_indicator.dart';
import 'import_screen.dart';

/// Buhay na roster: dagdag, palit ng pangalan, palit ng tier, pahinga, alis.
///
/// Lahat ng edit ay inline at isang tap — walang malalim na modal chain.
/// Ang pagtanggal ay may undo (R-03), walang confirmation dialog: mabilis
/// ang gabi at madalas ang maling pindot.
class RosterScreen extends ConsumerWidget {
  const RosterScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final playersAsync = ref.watch(playersProvider(sessionId));

    return Scaffold(
      body: playersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Empty(sessionId: sessionId),
        data: (synced) {
          final players = synced.data;
          if (players.isEmpty) return _Empty(sessionId: sessionId);

          final queued = players
              .where((p) => p.status == PlayerStatus.queued)
              .length;

          return Column(
            children: [
              SyncIndicator(hasPendingWrites: synced.hasPendingWrites),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      l10n.rosterCountSummary(players.length, queued),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                  itemCount: players.length,
                  itemBuilder: (context, index) => _PlayerTile(
                    sessionId: sessionId,
                    player: players[index],
                    allPlayers: players,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'addOne',
            tooltip: l10n.addPlayer,
            onPressed: () => _addPlayerDialog(context, ref),
            child: const Icon(Icons.person_add_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'paste',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImportScreen(sessionId: sessionId),
              ),
            ),
            icon: const Icon(Icons.content_paste),
            label: Text(l10n.pasteList),
          ),
        ],
      ),
    );
  }

  Future<void> _addPlayerDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var tier = SkillTier.intermediate;

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.addPlayerTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.playerNameLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) =>
                    Navigator.of(dialogContext).pop(value.trim()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(l10n.skillLabel),
                  const Spacer(),
                  SkillTierSelector(
                    value: tier,
                    onChanged: (value) => setState(() => tier = value),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(l10n.addPlayer),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (name == null || name.isEmpty) return;

    // Late arrival: pumapasok na may gamesPlayed ng pinakamababa sa aktibo,
    // kaya hindi siya lumulundag sa pila at hindi rin nalilibing.
    final current = ref.read(playersProvider(sessionId)).value?.data ?? const [];
    await ref.read(playerRepositoryProvider).addLateArrival(
          sessionId,
          NewPlayer(name: name, skillTier: tier),
          current,
        );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(l10n.rosterEmptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.rosterEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  const _PlayerTile({
    required this.sessionId,
    required this.player,
    required this.allPlayers,
  });

  final String sessionId;
  final SessionPlayer player;
  final List<SessionPlayer> allPlayers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = ref.read(playerRepositoryProvider);
    final hasLeft = player.status == PlayerStatus.left;

    return Dismissible(
      key: ValueKey(player.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final removed = player;
        await repo.removePlayer(sessionId, player.id);

        // Undo, hindi confirmation. Ang mali ay naibabalik sa isang tap
        // nang hindi pinapabagal ang bawat tamang pindot (R-15).
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.playerRemoved(removed.name)),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => repo.restorePlayer(sessionId, removed),
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Opacity(
          opacity: hasLeft ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: [
                SkillTierSelector(
                  value: player.skillTier,
                  onChanged: hasLeft
                      ? null
                      : (tier) => repo.updatePlayer(
                            sessionId,
                            player.id,
                            skillTier: tier,
                          ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => _renameDialog(context, repo, l10n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration:
                                  hasLeft ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            '${_statusLabel(l10n, player.status)} · '
                            '${l10n.gamesPlayedShort(player.gamesPlayed)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<PlayerStatus>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (status) => repo.updatePlayer(
                    sessionId,
                    player.id,
                    status: status,
                  ),
                  itemBuilder: (context) => [
                    if (player.status != PlayerStatus.queued)
                      PopupMenuItem(
                        value: PlayerStatus.queued,
                        child: Text(l10n.markQueued),
                      ),
                    if (player.status == PlayerStatus.queued)
                      PopupMenuItem(
                        value: PlayerStatus.resting,
                        child: Text(l10n.markResting),
                      ),
                    if (player.status != PlayerStatus.left)
                      PopupMenuItem(
                        value: PlayerStatus.left,
                        child: Text(l10n.markLeft),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, PlayerStatus status) {
    return switch (status) {
      PlayerStatus.queued => l10n.statusQueued,
      PlayerStatus.playing => l10n.statusPlaying,
      PlayerStatus.resting => l10n.statusResting,
      PlayerStatus.left => l10n.statusLeft,
    };
  }

  Future<void> _renameDialog(
    BuildContext context,
    PlayerRepository repo,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(text: player.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editPlayerTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.playerNameLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || name.isEmpty || name == player.name) return;
    await repo.updatePlayer(sessionId, player.id, name: name);
  }
}
