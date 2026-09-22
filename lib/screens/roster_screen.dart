import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../repositories/player_repository.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/skill_badge.dart';
import '../widgets/surfaces.dart';
import '../widgets/sync_indicator.dart';
import 'import_screen.dart';

/// Buhay na roster: dagdag, palit ng pangalan, palit ng tier, pahinga, alis.
///
/// Lahat ng edit ay inline at isang tap — walang malalim na modal chain.
/// Ang pagtanggal ay may undo (R-03), walang confirmation dialog: mabilis
/// ang gabi at madalas ang maling pindot.
///
/// BAKIT MAY SALAAN. Sa dalawampu't apat na pangalan, ang tanong ng QM ay
/// hindi "sino ang nandito" kundi **"sino ang nagpapahinga"** o "sino ang
/// umuwi na". Ang isang mahabang listahan ay hindi sumasagot niyan nang
/// hindi ka nag-i-scroll nang tatlong beses. Ang mga salaan sa itaas ay may
/// bilang, kaya nasasagot ang tanong bago pa mapindot.
class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  /// Null ang ibig sabihin ay lahat.
  PlayerStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionId = widget.sessionId;
    final playersAsync = ref.watch(playersProvider(sessionId));

    return Scaffold(
      backgroundColor: context.sq.canvas,
      body: playersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Empty(sessionId: sessionId),
        data: (synced) {
          final players = synced.data;
          if (players.isEmpty) return _Empty(sessionId: sessionId);

          final shown = _filter == null
              ? players
              : players.where((p) => p.status == _filter).toList();

          return Column(
            children: [
              SyncIndicator(hasPendingWrites: synced.hasPendingWrites),
              _FilterBar(
                players: players,
                selected: _filter,
                onSelect: (value) => setState(() => _filter = value),
                onPaste: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImportScreen(sessionId: sessionId),
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(
                          l10n.rosterFilterEmpty,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: context.sq.inkMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          SQSpace.lg,
                          SQSpace.xs,
                          SQSpace.lg,
                          104,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: SQSpace.sm),
                          child: SQEntrance(
                            // Susi ang pangalan: kapag nagpalit ng salaan,
                            // bagong pasok ang animasyon — kaya halatang
                            // nagbago ang listahan.
                            key: ValueKey('${_filter?.value}-${shown[index].id}'),
                            index: index,
                            child: _PlayerTile(
                              sessionId: sessionId,
                              player: shown[index],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      // Isang lumulutang na pindutan lang. Ang pagdagdag ng huling
      // dumating ay paulit-ulit hanggang alas-nuwebe, kaya ito ang nasa
      // hinlalaki; ang pag-paste ay isang beses lang sa simula ng gabi at
      // nasa hanay ng mga salaan sa itaas.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlayerDialog(context),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.addPlayer),
      ),
    );
  }

  Future<void> _addPlayerDialog(BuildContext context) async {
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
                decoration: InputDecoration(labelText: l10n.playerNameLabel),
                onSubmitted: (value) =>
                    Navigator.of(dialogContext).pop(value.trim()),
              ),
              const SizedBox(height: SQSpace.lg),
              Row(
                children: [
                  Text(
                    l10n.skillLabel,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
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
    final current =
        ref.read(playersProvider(widget.sessionId)).value?.data ?? const [];
    await ref.read(playerRepositoryProvider).addLateArrival(
          widget.sessionId,
          NewPlayer(name: name, skillTier: tier),
          current,
        );
  }
}

/// Mga salaan na may bilang. Ang bilang ang totoong laman nito — ang
/// pagpindot ay pangalawa lang.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.players,
    required this.selected,
    required this.onSelect,
    required this.onPaste,
  });

  final List<SessionPlayer> players;
  final PlayerStatus? selected;
  final ValueChanged<PlayerStatus?> onSelect;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    int count(PlayerStatus status) =>
        players.where((p) => p.status == status).length;

    final entries = <(PlayerStatus?, String, int, SQTone)>[
      (null, l10n.filterAll, players.length, SQTone.neutral),
      (
        PlayerStatus.queued,
        l10n.statusQueued,
        count(PlayerStatus.queued),
        SQTone.neutral,
      ),
      (
        PlayerStatus.playing,
        l10n.statusPlaying,
        count(PlayerStatus.playing),
        SQTone.live,
      ),
      (
        PlayerStatus.resting,
        l10n.statusResting,
        count(PlayerStatus.resting),
        SQTone.neutral,
      ),
      (
        PlayerStatus.left,
        l10n.statusLeft,
        count(PlayerStatus.left),
        SQTone.neutral,
      ),
    ];

    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: SQSpace.lg,
                vertical: SQSpace.md,
              ),
              children: [
                for (final (status, label, value, tone) in entries)
                  // Nawawala ang walang laman na salaan. Ang "Left early 0"
                  // ay hindi kapaki-pakinabang, at ang bawat karagdagang
                  // pindutan ay nagpapabagal sa paghahanap.
                  if (status == null || value > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: SQSpace.sm),
                      child: _FilterChip(
                        label: label,
                        count: value,
                        tone: tone,
                        selected: selected == status,
                        onTap: () => onSelect(status),
                      ),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: SQSpace.sm),
            child: IconButton(
              tooltip: l10n.pasteList,
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final SQTone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sq = context.sq;
    final tones = toneColors(context, tone);

    return SQPressable(
      onTap: onTap,
      scale: 0.94,
      borderRadius: SQRadius.pill,
      child: AnimatedContainer(
        duration: context.motion(SQDuration.state),
        curve: SQCurve.enter,
        padding: const EdgeInsets.symmetric(
          horizontal: SQSpace.md,
          vertical: SQSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? sq.ink : theme.colorScheme.surface,
          borderRadius: SQRadius.pill,
          border: Border.all(color: selected ? sq.ink : sq.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tone == SQTone.live && count > 0 && !selected) ...[
              SQLivePulse(color: tones.foreground, size: 6),
              const SizedBox(width: SQSpace.xs),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : sq.inkStrong,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.labelMedium
                  ?.copyWith(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.75)
                        : sq.inkFaint,
                  )
                  .tabular,
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SQEmptyState(
      icon: Icons.groups_outlined,
      title: l10n.rosterEmptyTitle,
      body: l10n.rosterEmptyBody,
      // Dati, ang walang lamang roster ay nagsasabi ng "i-paste ang listahan"
      // pero walang mapipindot para gawin iyon. Ngayon, nandito na ang
      // pinto sa mismong lugar kung saan itinuturo.
      action: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImportScreen(sessionId: sessionId),
          ),
        ),
        icon: const Icon(Icons.content_paste),
        label: Text(l10n.pasteList),
      ),
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  const _PlayerTile({required this.sessionId, required this.player});

  final String sessionId;
  final SessionPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;
    final repo = ref.read(playerRepositoryProvider);
    final hasLeft = player.status == PlayerStatus.left;
    final isPlaying = player.status == PlayerStatus.playing;

    return Dismissible(
      key: ValueKey(player.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: SQSpace.xl),
        decoration: BoxDecoration(
          color: sq.alarmWash,
          borderRadius: SQRadius.cardShape,
          border: Border.all(color: sq.alarm.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.removePlayer,
              style: theme.textTheme.labelMedium?.copyWith(color: sq.alarm),
            ),
            const SizedBox(width: SQSpace.sm),
            Icon(Icons.delete_outline, color: sq.alarm),
          ],
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
      child: Opacity(
        opacity: hasLeft ? 0.55 : 1,
        child: SQCard(
          tone: isPlaying ? SQTone.live : SQTone.neutral,
          padding: const EdgeInsets.fromLTRB(
            SQSpace.sm,
            SQSpace.xs,
            SQSpace.xs,
            SQSpace.xs,
          ),
          child: Row(
            children: [
              SkillTierSelector(
                value: player.skillTier,
                onChanged: hasLeft ? null : (tier) => _changeTier(ref, tier),
              ),
              const SizedBox(width: SQSpace.xs),
              Expanded(
                child: SQPressable(
                  onTap: () => _renameDialog(context, repo, l10n),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(SQRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SQSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration:
                                hasLeft ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (isPlaying) ...[
                              SQLivePulse(color: sq.live, size: 6),
                              const SizedBox(width: SQSpace.xs),
                            ],
                            Text(
                              _statusLabel(l10n, player.status),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isPlaying ? sq.live : sq.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Ang bilang ng laro ay nasa boses ng scoreboard: ito ang
              // sinusukat ng patas na pila, at ito ang tinitingnan ng QM
              // kapag may nagreklamo.
              SQCountUp(
                value: player.gamesPlayed,
                builder: (context, value) => Text(
                  value.round().toString(),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(
                        color: player.gamesPlayed == 0 ? sq.inkFaint : sq.ink,
                      )
                      .scoreboard,
                ),
              ),
              const SizedBox(width: SQSpace.xs),
              Text(
                l10n.boardGamesLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: sq.inkFaint),
              ),
              PopupMenuButton<PlayerStatus>(
                icon: Icon(Icons.more_vert, color: sq.inkFaint),
                onSelected: (status) =>
                    repo.updatePlayer(sessionId, player.id, status: status),
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
    );
  }

  /// Ang pagpalit ng tier ay tumatama sa dalawang lugar kapag regular ang
  /// manlalaro: ngayong gabi, **at** sa regulars book. Kung ngayong gabi lang,
  /// mali ulit ang tier sa susunod na linggo — at mawawala ang buong bentahe
  /// ng pag-alala.
  Future<void> _changeTier(WidgetRef ref, SkillTier tier) async {
    await ref.read(playerRepositoryProvider).updatePlayer(
          sessionId,
          player.id,
          skillTier: tier,
        );

    final memberId = player.memberId;
    final clubId = ref.read(defaultClubIdProvider).value;
    if (memberId != null && clubId != null) {
      await ref
          .read(clubRepositoryProvider)
          .updateMember(clubId, memberId, skillTier: tier);
    }
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
          decoration: InputDecoration(labelText: l10n.playerNameLabel),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
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
