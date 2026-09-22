import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/court.dart';
import '../models/enums.dart';
import '../models/match.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/skill_badge.dart';

/// Ang "Up Next" board — pangalawang screen na nakaharap sa lahat.
///
/// Sinasagot nito nang tuluyan ang pinakamadalas na tanong sa gabi:
/// *"Ate, kailan ako?"* Dati, kailangang sagutin ito ng QM nang paulit-ulit
/// habang abala siya. Ngayon, nasa pader na ang sagot.
///
/// TATLONG DESISYON SA DISENYO:
///  1. **Read-only.** Walang mapipindot maliban sa pag-alis. Ito ay
///     nakikita ng lahat, at walang dapat makagalaw ng pila kundi ang QM.
///  2. **Laging madilim.** Display screen ito, hindi app — mas madaling
///     basahin sa malayo at mas kaunti ang silaw sa gym.
///  3. **Kulay lang ang skill, walang salita.** Sa harap ng 24 katao,
///     mabigat ang makitang "beginner" ka (R-16). Ang QM lang ang
///     nakakakita ng aktwal na salita.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    // Walang saysay ang board na namamatay pagkalipas ng 30 segundo.
    //
    // Hindi natin ino-await ang Future na ito, kaya kung tanggihan ito ng
    // browser (hal. Wake Lock API na hindi suportado, o naka-battery saver),
    // magiging unhandled Zone error ito kung walang catchError. Walang
    // epekto sa datos kung mabigo ito — nananatili lang ang normal na
    // pag-timeout ng screen — kaya tahimik lang itong nilulunok.
    WakelockPlus.enable().catchError((Object _) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Ang oras ng paghihintay ay gumagalaw kahit walang bagong datos,
    // kaya kailangan ng sariling tibok — isang beses kada 20 segundo,
    // sapat para tumpak at hindi masyadong kumakain ng baterya.
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable().catchError((Object _) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final courts =
        ref.watch(courtsProvider(widget.sessionId)).value?.data ?? const [];
    final players =
        ref.watch(playersProvider(widget.sessionId)).value?.data ?? const [];
    final liveMatches = ref.watch(liveMatchesProvider(widget.sessionId));
    final queue = ref.watch(queueOrderProvider(widget.sessionId));

    final playersById = {for (final p in players) p.id: p};
    final isWide = MediaQuery.of(context).size.width > 900;

    return Theme(
      data: _boardTheme(),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _Courts(
                              courts: courts,
                              liveMatches: liveMatches,
                              playersById: playersById,
                              fill: true,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _Queue(queue: queue),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Courts(
                            courts: courts,
                            liveMatches: liveMatches,
                            playersById: playersById,
                          ),
                          const SizedBox(height: 20),
                          Expanded(child: _Queue(queue: queue)),
                        ],
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: l10n.boardExit,
                  icon: const Icon(Icons.close, color: Colors.white24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _bg = Color(0xFF0B1410);
const _card = Color(0xFF16241D);
const _accent = Color(0xFF5FD495);

ThemeData _boardTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    // Kasama ang pamilya ng font: may sariling Theme ang board, at kung
    // hindi ito sasabihin ay Roboto ang lalabas sa TV habang Inter ang
    // nasa telepono ng QM. Dalawang magkaibang app ang magmumukha nito.
    fontFamily: kTextFamily,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      surface: _card,
    ),
  );
}

class _Courts extends StatelessWidget {
  const _Courts({
    required this.courts,
    required this.liveMatches,
    required this.playersById,
    this.fill = false,
  });

  final List<Court> courts;
  final Map<String, GameMatch> liveMatches;
  final Map<String, SessionPlayer> playersById;

  /// Sa malapad na screen, pinaghahatian ng mga court ang buong taas.
  /// Sa telepono ay hindi — naka-Column siya roon na walang hangganan.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final panels = [
      for (final court in courts)
        _CourtPanel(
          court: court,
          match: liveMatches[court.id],
          playersById: playersById,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final panel in panels)
          if (fill) Expanded(child: panel) else panel,
      ],
    );
  }
}

class _CourtPanel extends StatelessWidget {
  const _CourtPanel({
    required this.court,
    required this.match,
    required this.playersById,
  });

  final Court court;
  final GameMatch? match;
  final Map<String, SessionPlayer> playersById;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPlaying = match != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? _accent.withValues(alpha: 0.5) : Colors.white10,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 124,
            child: Row(
              children: [
                // Ang tumitibok na tuldok ang nagsasabing buhay ang
                // screen. Sa TV na nakasabit buong gabi, ito ang
                // pagkakaiba ng "live" at "na-freeze kanina pa".
                if (isPlaying) ...[
                  SQLivePulse(color: _accent, size: 8),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    court.label,
                    style: TextStyle(
                      color: isPlaying ? Colors.white : Colors.white38,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ).scoreboard,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isPlaying
                ? Row(
                    children: [
                      Expanded(child: _Team(ids: match!.teamA, playersById: playersById)),
                      // Lambat, hindi salita: ang parehong motif ng
                      // courts screen, nakatayo dahil magkatabi ang
                      // dalawang panig dito.
                      Container(
                        width: 2,
                        height: 58,
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Expanded(child: _Team(ids: match!.teamB, playersById: playersById)),
                    ],
                  )
                : Text(
                    l10n.boardCourtFree,
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({required this.ids, required this.playersById});

  final List<String> ids;
  final Map<String, SessionPlayer> playersById;

  @override
  Widget build(BuildContext context) {
    final players = ids.map((id) => playersById[id]).nonNulls.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final player in players)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                _TierDot(tier: player.skillTier),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kulay lang — walang salitang "beginner" sa harap ng lahat (R-16).
class _TierDot extends StatelessWidget {
  const _TierDot({required this.tier});

  final SkillTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: skillColor(context, tier),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.queue});

  final List<SessionPlayer> queue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.boardUpNext.toUpperCase(),
              style: const TextStyle(
                color: _accent,
                fontSize: 19,
                letterSpacing: 2,
              ).scoreboard,
            ),
            const Spacer(),
            // May puwang sa kanan: nandoon ang pindutang isara, at
            // nagkakapatong sila noon sa malapad na screen.
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(
                l10n.boardPlayersWaiting(queue.length),
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (queue.isEmpty)
          Text(
            l10n.boardNobodyWaiting,
            style: const TextStyle(color: Colors.white24, fontSize: 22),
          )
        else
          Expanded(
            child: ListView.builder(
              // Ang unang apat ang malamang na susunod — mas malaki sila.
              itemCount: queue.length,
              itemBuilder: (context, index) => _QueueRow(
                position: index + 1,
                player: queue[index],
                now: now,
                isNextUp: index < 4,
              ),
            ),
          ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.position,
    required this.player,
    required this.now,
    required this.isNextUp,
  });

  final int position;
  final SessionPlayer player;
  final DateTime now;
  final bool isNextUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final waited = now.difference(player.waitingSince).inMinutes;
    final safeWait = waited < 0 ? 0 : waited;

    // Matagal nang naghihintay — kitang-kita ito ng lahat, kasama ng QM.
    // Ito ang panlabas na anyo ng long-wait guarantee (R-05).
    final isLongWait = safeWait >= 25;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$position',
              style: TextStyle(
                color: isNextUp ? _accent : Colors.white24,
                fontSize: isNextUp ? 25 : 19,
              ).scoreboard,
            ),
          ),
          _TierDot(tier: player.skillTier),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              style: TextStyle(
                color: isNextUp ? Colors.white : Colors.white60,
                fontSize: isNextUp ? 26 : 21,
                fontWeight: isNextUp ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Transparency: nakikita ng lahat kung ilan na ang laro ng bawat
          // isa. Ito ang pumapatay sa tanim na tampo na "bakit siya laging
          // naglalaro?" — mas mabisa pa ito kaysa sa algorithm mismo.
          Text(
            l10n.boardGamesCount(player.gamesPlayed),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 21,
            ).scoreboard,
          ),
          const SizedBox(width: 4),
          Text(
            l10n.boardGamesLabel,
            style: const TextStyle(color: Colors.white24, fontSize: 14),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 52,
            child: Text(
              l10n.boardWaitingFor(safeWait),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isLongWait ? const Color(0xFFE8A33D) : Colors.white38,
                fontSize: 18,
                fontWeight: isLongWait ? FontWeight.w600 : FontWeight.w500,
              ).tabular,
            ),
          ),
        ],
      ),
    );
  }
}
