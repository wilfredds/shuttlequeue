import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../services/matchmaking_service.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/player_avatar.dart';
import '../widgets/skill_badge.dart';
import '../widgets/surfaces.dart';
import '../widgets/sync_indicator.dart';

/// Ang pangunahing screen ng QM habang tumatakbo ang gabi.
///
/// ANG HUGIS NG SCREEN AY ANG HUGIS NG GYM. Ang bawat court ay isang kard
/// na may **lambat sa gitna** — dalawang panig, magkaharap. Kapag tumingin
/// ang QM sa telepono niya, ang nakikita niya ay ang parehong ayos ng
/// nakikita niya kapag tumingala siya.
///
/// Isang malaking aksyon lang ang nangingibabaw sa ilalim — **Next
/// match** — at kapag hindi ito pwede, nakasulat kung bakit. Ang
/// naka-dim na pindutan na walang paliwanag ay ang pinakamabilis na
/// paraan para sumuko ang isang tao sa isang app.
class CourtsScreen extends ConsumerStatefulWidget {
  const CourtsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends ConsumerState<CourtsScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Gumagalaw ang oras kahit walang bagong datos mula sa Firestore. Kung
    // walang sariling tibok, mananatiling "3m" ang isang laro na 40 minuto
    // nang tumatakbo — at doon nawawala ang tiwala sa buong screen.
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        // Walang gumagalaw sa tapos nang gabi, kaya walang dapat iguhit
        // muli. Ang telepono ng QM ang buong sistema; huwag itong ubusin
        // sa pag-redraw ng mga bilang na hindi na nagbabago.
        if (!mounted) return;
        final session = ref.read(sessionProvider(widget.sessionId)).value;
        if (session?.status == SessionStatus.ended) return;
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionId = widget.sessionId;

    final courtsSynced = ref.watch(courtsProvider(sessionId)).value;
    final playersSynced = ref.watch(playersProvider(sessionId)).value;
    final courts = courtsSynced?.data ?? const [];
    final players = playersSynced?.data ?? const [];
    final pendingWrites = (courtsSynced?.hasPendingWrites ?? false) ||
        (playersSynced?.hasPendingWrites ?? false);
    final liveMatches = ref.watch(liveMatchesProvider(sessionId));
    final queue = ref.watch(queueOrderProvider(sessionId));

    // Tapos na ba ang gabi? Dito nakasalalay kung may umaandar pang orasan.
    //
    // ANG BUG NA ITO AY GALING SA TOTOONG GABI: walang paraan noon para
    // tapusin ang session, kaya nanatili itong `live` magpakailanman — at
    // ang oras ng paghihintay ng bawat tao ay patuloy na lumaki nang walang
    // hanggan. Pagbalik mo kinabukasan, "1,340m wait" ang nakasulat sa
    // tabi ng lahat. Ang bilang na walang katotohanan ay mas masahol pa
    // kaysa walang bilang.
    final ended =
        ref.watch(sessionProvider(sessionId)).value?.status ==
            SessionStatus.ended;

    final playersById = {for (final p in players) p.id: p};
    final freeCourt = courts.where((c) => c.isFree).firstOrNull;
    final canStart = !ended && freeCourt != null && queue.length >= 4;

    return Scaffold(
      backgroundColor: context.sq.canvas,
      body: SafeArea(
        child: Column(
          children: [
            SyncIndicator(hasPendingWrites: pendingWrites),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SQSpace.lg,
                  SQSpace.md,
                  SQSpace.lg,
                  SQSpace.lg,
                ),
                children: [
                  for (var i = 0; i < courts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SQSpace.md),
                      child: SQEntrance(
                        index: i,
                        child: _CourtCard(
                          sessionId: sessionId,
                          court: courts[i],
                          match: liveMatches[courts[i].id],
                          playersById: playersById,
                          onStart: queue.length >= 4
                              ? () => _showSuggestion(context, courts[i])
                              : null,
                        ),
                      ),
                    ),
                  _QueueSection(queue: queue, ended: ended),
                ],
              ),
            ),
            _CommandBar(
              enabled: canStart,
              // Kapag naka-dim ang pindutan, sinasabi kung bakit — at ang
              // dahilan ay may kasamang gagawin, hindi lang balita.
              reason: ended
                  ? l10n.courtsEndedBody
                  : courts.isEmpty
                      ? null
                      : freeCourt == null
                          ? l10n.allCourtsBusy
                          : queue.length < 4
                              ? l10n.needFourPlayers
                              : null,
              // Kapag puwede nang magsimula, ang puwang na iyon ay
              // sinasabi kung SINO ang susunod. Ito ang tanong na
              // paulit-ulit itinatanong sa QM buong gabi, at dati ay
              // kailangan pang mag-scroll pababa para sagutin.
              nextUp: canStart
                  ? queue.take(4).map((p) => p.name).join(' · ')
                  : null,
              onPressed: canStart
                  ? () => _showSuggestion(context, freeCourt)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuggestion(BuildContext context, Court court) async {
    final sessionId = widget.sessionId;
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

/// Isang court, sa dalawang anyo: may laro, o bakante.
///
/// Ang may laro ay may kulay, may anino, at may tumitibok na tuldok. Ang
/// bakante ay may putol-putol na hangganan at halos walang bigat — kaya sa
/// isang sulyap, ang bilang ng *gumagalaw* na kard ang bilang ng laro.
class _CourtCard extends ConsumerWidget {
  const _CourtCard({
    required this.sessionId,
    required this.court,
    required this.match,
    required this.playersById,
    required this.onStart,
  });

  final String sessionId;
  final Court court;
  final GameMatch? match;
  final Map<String, SessionPlayer> playersById;

  /// Null kapag kulang pa ang tao sa pila.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;

    if (match == null) {
      return _FreeCourt(label: court.label, onStart: onStart);
    }

    final live = match!;
    final elapsed = DateTime.now().difference(live.startedAt);
    final minutes = elapsed.inMinutes;

    // Lumagpas na sa karaniwang haba ng isang laro ng doubles. Walang
    // pinipigilan dito — pahiwatig lang na malapit nang bumakante.
    const longGame = Duration(minutes: 20);
    final isLong = elapsed >= longGame;

    final card = SQCard(
      tone: SQTone.live,
      lifted: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ang ulo ng kard ay ang berde ng court. Dito nakasulat ang
          // numero sa boses ng scoreboard — ito ang binabasa mula sa
          // kabilang dulo ng mesa.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SQSpace.lg,
              vertical: SQSpace.sm,
            ),
            decoration: BoxDecoration(
              color: sq.live,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SQRadius.lg - 1),
              ),
            ),
            child: Row(
              children: [
                SQLivePulse(color: Colors.white, size: 7),
                const SizedBox(width: SQSpace.sm),
                Expanded(
                  child: Text(
                    court.label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.6,
                        )
                        .scoreboard,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  l10n.courtPlayingFor(minutes < 0 ? 0 : minutes),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(
                        color: isLong
                            ? sq.attentionWash
                            : Colors.white.withValues(alpha: 0.85),
                        fontWeight: isLong ? FontWeight.w600 : null,
                      )
                      .tabular,
                ),
              ],
            ),
          ),

          // Ang oras bilang guhit, hindi lang bilang teksto. Nakikita ito
          // sa gilid ng mata habang may kausap ang QM.
          SQGameProgress(elapsed: elapsed, longGame: longGame),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SQSpace.lg,
              SQSpace.sm,
              SQSpace.lg,
              SQSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ang key na nakatali sa match id ang nagpapatakbo muli ng
                // pagpasok sa bawat BAGONG laro — at hindi sa bawat rebuild
                // (tumitibok ang minuto sa ulo ng kard kada minuto).
                _TeamSide(
                  key: ValueKey('a-${live.id}'),
                  sessionId: sessionId,
                  match: live,
                  fromLeft: true,
                  players:
                      live.teamA.map((id) => playersById[id]).nonNulls.toList(),
                ),
                const _NetLine(),
                _TeamSide(
                  key: ValueKey('b-${live.id}'),
                  sessionId: sessionId,
                  match: live,
                  fromLeft: false,
                  players:
                      live.teamB.map((id) => playersById[id]).nonNulls.toList(),
                ),
                const SizedBox(height: SQSpace.sm),
                // Isang linya ang pahiwatig at nasa sarili nitong hanay.
                // Noong nakatabi ito ng mga pindutan, tatlong linya ito sa
                // 390pt na telepono at naipit ang buong ilalim ng kard.
                Text(
                  l10n.substituteHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: sq.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SQSpace.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => ref
                          .read(matchRepositoryProvider)
                          .cancelMatch(sessionId: sessionId, match: live),
                      style: TextButton.styleFrom(foregroundColor: sq.inkMuted),
                      child: Text(l10n.cancelMatch),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(
                          horizontal: SQSpace.lg,
                        ),
                      ),
                      onPressed: () => _finish(context, ref),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.endMatch),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Humihinga lang ang court na lumagpas na sa karaniwang haba. Tingnan
    // ang SQLongGameBreath kung bakit hindi lahat ng live court.
    return SQLongGameBreath(active: isLong, child: card);
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

/// Bakanteng court: mapipindot, at sinasabi kung ano ang mangyayari.
class _FreeCourt extends StatelessWidget {
  const _FreeCourt({required this.label, required this.onStart});

  final String label;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;
    final ready = onStart != null;

    return SQPressable(
      onTap: onStart,
      haptic: HapticLevel.impact,
      child: CustomPaint(
        // Putol-putol ang hangganan: ang bakanteng court ay isang
        // **puwang**, hindi isang bagay. Kaya hindi ito nakikipag-agawan
        // ng pansin sa mga court na may laro.
        painter: _DashedBorderPainter(color: sq.line),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SQSpace.lg,
            vertical: SQSpace.lg,
          ),
          constraints: const BoxConstraints(minHeight: 84),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: sq.inkMuted, letterSpacing: 0.6)
                          .scoreboard,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready ? l10n.queueReady : l10n.courtFree,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ready ? sq.attention : sq.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (ready)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sq.liveWash,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sq.live.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: sq.live),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ang lambat. Isang linya lang, pero ito ang nagpapaliwanag sa buong kard
/// nang walang salita: ang nasa itaas at ang nasa ibaba ay magkalaban.
class _NetLine extends StatelessWidget {
  const _NetLine();

  @override
  Widget build(BuildContext context) {
    final sq = context.sq;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SQSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: sq.live.withValues(alpha: 0.3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SQSpace.sm),
            child: Text(
              'vs',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: sq.live.withValues(alpha: 0.7)),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: sq.live.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(SQRadius.lg),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 6),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// Isang panig ng court. Ang bawat pangalan ay napipindot para palitan ang
/// taong iyon nang hindi kinakansela ang buong laro.
class _TeamSide extends ConsumerWidget {
  const _TeamSide({
    super.key,
    required this.sessionId,
    required this.match,
    required this.players,
    required this.fromLeft,
  });

  final String sessionId;
  final GameMatch match;
  final List<SessionPlayer> players;

  /// Aling panig ng net — ito ang nagsasabi kung saan galing ang pagpasok.
  final bool fromLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sq = context.sq;

    return Row(
      children: [
        for (final (index, player) in players.indexed)
          Expanded(
            child: SQCourtArrival(
              fromLeft: fromLeft,
              index: index,
              child: SQPressable(
              onTap: () => _substitute(context, ref, player),
              borderRadius: const BorderRadius.all(
                Radius.circular(SQRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SQSpace.xs,
                  vertical: SQSpace.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatar(
                      name: player.name,
                      seed: player.avatarSeed,
                      size: 26,
                      ringColor: skillColor(context, player.skillTier),
                    ),
                    const SizedBox(width: SQSpace.sm),
                    Expanded(
                      child: Text(
                        player.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: sq.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  ),
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
      messenger.showSnackBar(SnackBar(content: Text(l10n.substituteNobody)));
      return;
    }

    final incoming = await showModalBottomSheet<SessionPlayer>(
      context: context,
      // Nasa pagkakasunod-sunod ng pila — kaya ang mungkahi ay ang
      // parehong taong susunod na maglalaro.
      builder: (sheetContext) => _PickPlayerSheet(
        title: l10n.substituteTitle(outgoing.name),
        options: queue,
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

/// Ang pila, at ang sagot sa "patas ba?"
///
/// Ang unang apat ay magkasama sa isang kahon: sila ang susunod na laro.
/// Ang natitira ay listahan lang. Ang agwat ng bilang ng laro ay nasa
/// pamagat — ito ang pangako ng app, at dapat nakikita, hindi ipinapangako
/// lang.
class _QueueSection extends StatelessWidget {
  const _QueueSection({required this.queue, this.ended = false});

  final List<SessionPlayer> queue;

  /// Tapos na ang gabi: nananatili ang pila para makita pa rin kung sino
  /// ang nandoon, pero huminto na ang orasan.
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;

    if (queue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: SQSpace.xl),
        child: SQCard(
          padding: const EdgeInsets.symmetric(vertical: SQSpace.xxl),
          child: Center(
            child: Text(
              l10n.upNextEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(color: sq.inkMuted),
            ),
          ),
        ),
      );
    }

    final games = queue.map((p) => p.gamesPlayed).toList()..sort();
    final low = games.first;
    final high = games.last;
    final now = DateTime.now();
    final longest = queue
        .map((p) => now.difference(p.waitingSince).inMinutes)
        .fold(0, (a, b) => b > a ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SQSectionHeading(
          title: l10n.upNext,
          count: queue.length,
          action: SQStatusPill(
            dense: true,
            // Ang patas na pila ay ang buong dahilan ng app. Kapag
            // lumampas sa isang laro ang agwat, amber ito — hindi para
            // magalit, para makita ng QM bago may magreklamo.
            tone: high - low <= 1 ? SQTone.live : SQTone.attention,
            label: high - low <= 1
                ? l10n.fairnessEven
                : l10n.fairnessSpread(low, high),
          ),
        ),
        SQCard(
          padding: const EdgeInsets.symmetric(vertical: SQSpace.xs),
          child: Column(
            children: [
              for (var i = 0; i < queue.length && i < 12; i++) ...[
                if (i == 4) SQHairline(indent: SQSpace.lg + 28),
                _QueueRow(
                  player: queue[i],
                  position: i + 1,
                  // Ang unang apat ay ang susunod na laro. Sila ang
                  // may kulay; ang iba ay konteksto.
                  upNext: i < 4,
                  waitedMinutes:
                      now.difference(queue[i].waitingSince).inMinutes,
                  ended: ended,
                ),
              ],
              if (queue.length > 12)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SQSpace.lg,
                    SQSpace.sm,
                    SQSpace.lg,
                    SQSpace.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.boardMoreWaiting(queue.length - 12),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: sq.inkFaint),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (longest >= 20) ...[
          const SizedBox(height: SQSpace.sm),
          Row(
            children: [
              Icon(Icons.hourglass_bottom, size: 15, color: sq.attention),
              const SizedBox(width: SQSpace.xs),
              Text(
                l10n.waitingLongest(longest),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: sq.attention)
                    .tabular,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.player,
    required this.position,
    required this.upNext,
    required this.waitedMinutes,
    this.ended = false,
  });

  final SessionPlayer player;
  final int position;
  final bool upNext;
  final int waitedMinutes;

  /// Huminto na ang orasan. Hindi natin iniimbak ang huling hintay, kaya
  /// gitling ang ipinapakita — mas tapat iyon kaysa sa bilang na patuloy
  /// na lumalaki matapos nang matapos ang gabi.
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SQSpace.lg,
        vertical: SQSpace.sm,
      ),
      child: Row(
        children: [
          // Ang posisyon sa pila ay ang una at pinakamadalas na tanong.
          // Nasa boses ng scoreboard siya kaya nababasa nang hindi
          // tinitingnan nang diretso.
          SizedBox(
            width: 28,
            child: Text(
              '$position',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: upNext ? sq.live : sq.inkFaint)
                  .scoreboard,
            ),
          ),
          // Ang mukha ang nagdadala ng DALAWANG trabaho dito: kung sino,
          // at kung anong tier (ang singsing). Ang hilera sa pila ay may
          // anim nang bagay sa loob ng 360dp; ang hiwalay na badge para sa
          // tier ay magpapaikli sa pangalan hanggang sa mag-ellipsis na
          // ang kalahati ng roster.
          PlayerAvatar(
            name: player.name,
            seed: player.avatarSeed,
            size: 28,
            ringColor: skillColor(context, player.skillTier),
          ),
          const SizedBox(width: SQSpace.sm),
          Expanded(
            child: Text(
              player.name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: upNext ? sq.ink : sq.inkStrong,
                fontWeight: upNext ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            l10n.gamesPlayedShort(player.gamesPlayed),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: sq.inkMuted)
                .tabular,
          ),
          const SizedBox(width: SQSpace.md),
          SizedBox(
            width: 44,
            child: Text(
              ended
                  ? '—'
                  : l10n.waitingTime(waitedMinutes < 0 ? 0 : waitedMinutes),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall
                  ?.copyWith(
                    color: !ended && waitedMinutes >= 20
                        ? sq.attention
                        : sq.inkFaint,
                  )
                  .tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ang bar sa ilalim: isang aksyon, at kung bakit hindi pwede.
class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.enabled,
    required this.reason,
    required this.nextUp,
    required this.onPressed,
  });

  final bool enabled;
  final String? reason;

  /// Ang apat na susunod, pinaghiwalay ng tuldok. Null kapag hindi pa
  /// puwedeng magsimula — doon, ang dahilan ang mas kailangan.
  final String? nextUp;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;

    return SQCommandBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Walang AnimatedSize dito nang sinasadya: ang linyang ito ay
          // bihirang magbago, at ang pagsukat habang sinusukat ay nagdulot
          // ng crash sa layout. Ang galaw ay hindi sulit sa panganib.
          Builder(
            builder: (context) => reason == null && nextUp == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: SQSpace.sm),
                    child: Row(
                      children: [
                        Icon(
                          nextUp != null
                              ? Icons.arrow_forward_rounded
                              : Icons.info_outline,
                          size: 15,
                          color: nextUp != null ? sq.live : sq.inkFaint,
                        ),
                        const SizedBox(width: SQSpace.xs),
                        Expanded(
                          child: Text(
                            nextUp != null
                                ? l10n.nextUpNames(nextUp!)
                                : reason!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: nextUp != null ? sq.inkStrong : sq.inkMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: Text(
                l10n.nextMatch,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 19,
                  color: enabled ? Colors.white : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isang listahan ng pwedeng piliin — ginagamit ng swap at ng substitute.
class _PickPlayerSheet extends StatelessWidget {
  const _PickPlayerSheet({required this.title, required this.options});

  final String title;
  final List<SessionPlayer> options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: SQSpace.sm),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SQSpace.xl,
              SQSpace.sm,
              SQSpace.xl,
              SQSpace.md,
            ),
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          for (var i = 0; i < options.length; i++)
            ListTile(
              leading: SizedBox(
                width: 46,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: context.sq.inkFaint)
                            .tabular,
                      ),
                    ),
                    SkillBadge(tier: options[i].skillTier, size: 26),
                  ],
                ),
              ),
              title: Text(options[i].name),
              subtitle: Text(l10n.gamesPlayedShort(options[i].gamesPlayed)),
              onTap: () => Navigator.of(context).pop(options[i]),
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
      builder: (sheetContext) =>
          _PickPlayerSheet(title: l10n.swapTitle, options: options),
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
    final sq = context.sq;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SQSpace.xl,
          SQSpace.sm,
          SQSpace.xl,
          SQSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.suggestionTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                SQStatusPill(
                  label: widget.court.label,
                  tone: SQTone.live,
                  icon: Icons.stadium_outlined,
                ),
              ],
            ),
            const SizedBox(height: SQSpace.md),

            // Hindi hinaharangan ang laro — binabalaan lang ang QM (spec §5.4).
            if (widget.suggestion.isMixedSkill)
              _Notice(
                icon: Icons.balance,
                text: l10n.suggestionMixedSkill,
                tone: SQTone.neutral,
              ),
            for (final forced in widget.suggestion.forcedByLongWait)
              _Notice(
                icon: Icons.hourglass_bottom,
                text: l10n.suggestionForcedWait(forced.name),
                tone: SQTone.attention,
              ),

            const SizedBox(height: SQSpace.xs),
            SQCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SQSpace.md,
                vertical: SQSpace.sm,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _four.length; i++) ...[
                    if (i == 2) const _NetLine(),
                    Row(
                      children: [
                        // Dito, ang tier ang mismong desisyon — kaya nananatili
                        // ang titik. Ang mukha ay para sa pagtutugma ng pangalan
                        // sa taong nasa harap ng QM habang pinipili niya kung
                        // sino ang palitan.
                        PlayerAvatar(
                          name: _four[i].name,
                          seed: _four[i].avatarSeed,
                          size: 34,
                        ),
                        const SizedBox(width: SQSpace.sm),
                        SkillBadge(tier: _four[i].skillTier, size: 26),
                        const SizedBox(width: SQSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _four[i].name,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l10n.gamesPlayedShort(_four[i].gamesPlayed),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: sq.inkMuted)
                                    .tabular,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _swap(i),
                          child: Text(l10n.swapPlayer),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: SQSpace.xl),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _isStarting ? null : _start,
                icon: _isStarting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 26),
                label: Text(l10n.startMatch(widget.court.label)),
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
    required this.tone,
  });

  final IconData icon;
  final String text;
  final SQTone tone;

  @override
  Widget build(BuildContext context) {
    final tones = toneColors(context, tone);

    return Container(
      margin: const EdgeInsets.only(bottom: SQSpace.sm),
      padding: const EdgeInsets.all(SQSpace.md),
      decoration: BoxDecoration(
        color: tones.background,
        borderRadius: const BorderRadius.all(Radius.circular(SQRadius.md)),
        border: Border.all(color: tones.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tones.foreground),
          const SizedBox(width: SQSpace.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tones.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
