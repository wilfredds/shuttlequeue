import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../providers/session_providers.dart';
import '../services/session_snapshot.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import 'board_screen.dart';
import 'end_session_action.dart';
import 'cost_split_screen.dart';
import 'courts_screen.dart';
import 'recap_screen.dart';
import 'roster_screen.dart';
import 'session_form_screen.dart';

/// Ang bahay ng QM sa loob ng isang gabi, sunod-sunod ang mga yugto:
/// sino ang nandito, sino ang naglalaro, magkano ang bayad, at kumusta
/// ang gabi.
///
/// DALAWANG BAGAY DITO ANG HINDI PALAMUTI:
///
/// 1. **Nasa itaas ang estado ng gabi.** Kahit nasa Money tab ang QM,
///    alam niyang tatlo ang nasa court at siyam ang naghihintay nang
///    hindi bumabalik sa Courts.
/// 2. **May bilang ang mga tab — kapag may dapat gawin lang.** Kapag may
///    bakanteng court at sapat ang tao sa pila, may amber na bilang sa
///    Courts: "pwede ka nang magpasimula". Kapag naka-lock na ang bill,
///    ang Money naman: ilan pa ang hindi bayad. Walang bilang kapag
///    walang aasikasuhin — kaya kapag may nakita, totoo.
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  var _tabIndex = 0;

  /// Buong larawan ng gabi bilang text, ibinabahagi sa OS share sheet.
  /// Puro lokal ang lahat, kaya gumagana ito offline.
  Future<void> _shareSnapshot(BuildContext context) async {
    final session = ref.read(sessionProvider(widget.sessionId)).value;
    if (session == null) return;

    final text = buildSessionSnapshot(
      session: session,
      players: ref.read(playersProvider(widget.sessionId)).value?.data ?? const [],
      courts: ref.read(courtsProvider(widget.sessionId)).value?.data ?? const [],
      matches: ref.read(matchesProvider(widget.sessionId)).value ?? const [],
      now: DateTime.now(),
    );

    await SharePlus.instance.share(
      ShareParams(text: text, subject: session.title),
    );
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;

    final session = ref.watch(sessionProvider(widget.sessionId)).value;
    final players =
        ref.watch(playersProvider(widget.sessionId)).value?.data ?? const [];
    final courts =
        ref.watch(courtsProvider(widget.sessionId)).value?.data ?? const [];
    final queue = ref.watch(queueOrderProvider(widget.sessionId));

    // Sinasadyang pinapanood kahit hindi ginagamit dito.
    //
    // Binabasa ito ng _shareSnapshot sa pamamagitan ng `read`, at ang isang
    // StreamProvider na walang nanonood ay nagbabalik ng wala habang naka-
    // loading pa. Kung hindi pa nabubuksan ng QM ang Courts tab, ang "Save
    // a copy of tonight" ay maglalabas ng papel na walang kahit isang laro
    // — at iyon ang mismong kopyang pinagkakatiwalaan kapag patay na ang
    // baterya. Ang papel na mukhang buo pero walang laman ay mas masahol
    // pa kaysa sa walang papel.
    ref.watch(matchesProvider(widget.sessionId));

    final onCourt =
        players.where((p) => p.status == PlayerStatus.playing).length;
    final freeCourts = courts.where((c) => c.status == CourtStatus.free).length;
    final unpaid = players.where((p) => !p.hasPaid).length;

    // Lumalabas lang ang bilang sa Courts kapag may **magagawa**: may
    // bakanteng court at may sapat na tao para punuin ito.
    final canStartNow = freeCourts > 0 && queue.length >= 4;
    // Ang Money ay naghihintay sa lock. Bago iyon, lahat ay hindi pa
    // bayad — at ang bilang na laging nandiyan ay hindi na napapansin.
    final collecting = session?.billFinalizedAt != null && unpaid > 0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session?.title ?? l10n.appTitle,
              style: theme.textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                if (session?.status == SessionStatus.live) ...[
                  SQLivePulse(color: sq.live, size: 6),
                  const SizedBox(width: SQSpace.xs),
                  Text(
                    l10n.sessionStatusLive.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: sq.live),
                  ),
                  _Sep(),
                ],
                // Dati, ang tapos na gabi ay kamukhang-kamukha ng tumatakbo
                // pa. Walang nagsasabi kung alin ang alin.
                if (session?.status == SessionStatus.ended) ...[
                  Icon(Icons.check_circle, size: 11, color: sq.inkMuted),
                  const SizedBox(width: SQSpace.xs),
                  Text(
                    l10n.sessionStatusEnded.toUpperCase(),
                    style:
                        theme.textTheme.labelSmall?.copyWith(color: sq.inkMuted),
                  ),
                  _Sep(),
                ],
                Text(
                  l10n.detailOnCourt(onCourt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: sq.inkMuted)
                      .tabular,
                ),
                _Sep(),
                Flexible(
                  child: Text(
                    l10n.boardPlayersWaiting(queue.length),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: sq.inkMuted)
                        .tabular,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (session != null) ...[
            // Ang board ay para sa pangalawang screen — tablet, laptop, o
            // TV na nakaharap sa lahat. Sinasagot nito ang "kailan ako?"
            // nang hindi na kailangang magsalita ang QM.
            IconButton(
              tooltip: l10n.openBoard,
              icon: const Icon(Icons.tv_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BoardScreen(sessionId: widget.sessionId),
                ),
              ),
            ),
            // R-01: ang telepono ng QM ang buong sistema. Isang tap dito at
            // may kopya na siya ng buong gabi na kaya niyang i-paste kahit
            // saan — gumagana kahit walang signal.
            IconButton(
              tooltip: l10n.saveSnapshot,
              icon: const Icon(Icons.save_alt),
              onPressed: () => _shareSnapshot(context),
            ),
            IconButton(
              tooltip: l10n.editSessionTitle,
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionFormScreen(existing: session),
                ),
              ),
            ),
            // Ang pagtatapos ng gabi ay dapat may sariling pindutan. Dati,
            // ang tanging daan ay ang "Lock the amounts" sa Money tab —
            // hindi ito nahanap ng totoong QM, dahil hindi iyon ang
            // tinatanong niya.
            PopupMenuButton<String>(
              tooltip: l10n.endSession,
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'end') confirmEndSession(context, ref, widget.sessionId);
                if (value == 'resume') resumeSession(context, ref, widget.sessionId);
              },
              itemBuilder: (context) => [
                if (session.status != SessionStatus.ended)
                  PopupMenuItem(
                    value: 'end',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 20),
                        const SizedBox(width: SQSpace.md),
                        Text(l10n.endSession),
                      ],
                    ),
                  )
                else
                  PopupMenuItem(
                    value: 'resume',
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_outlined, size: 20),
                        const SizedBox(width: SQSpace.md),
                        Text(l10n.resumeSession),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(width: SQSpace.xs),
        ],
      ),
      // Hindi biglang napapalitan ang laman: kumukupas ang luma habang
      // umaangat ang bago. Sa isang tab bar na apat ang pinagpipilian, ito
      // ang nagsasabing lumipat ka — hindi nag-reload ang app.
      body: AnimatedSwitcher(
        duration: context.motion(SQDuration.state),
        switchInCurve: SQCurve.enter,
        switchOutCurve: SQCurve.exit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            ?current,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(_tabIndex),
          child: switch (_tabIndex) {
            0 => RosterScreen(sessionId: widget.sessionId),
            1 => CourtsScreen(sessionId: widget.sessionId),
            2 => CostSplitScreen(sessionId: widget.sessionId),
            _ => RecapScreen(sessionId: widget.sessionId),
          },
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: sq.lineSoft)),
        ),
        child: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: sq.liveWash,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups, color: sq.live),
              label: l10n.tabRoster,
            ),
            NavigationDestination(
              icon: _Counted(
                icon: Icons.grid_view_outlined,
                count: canStartNow ? freeCourts : null,
              ),
              selectedIcon: _Counted(
                icon: Icons.grid_view,
                count: canStartNow ? freeCourts : null,
                color: sq.live,
              ),
              label: l10n.tabCourts,
            ),
            NavigationDestination(
              icon: _Counted(
                icon: Icons.payments_outlined,
                count: collecting ? unpaid : null,
              ),
              selectedIcon: _Counted(
                icon: Icons.payments,
                count: collecting ? unpaid : null,
                color: sq.live,
              ),
              label: l10n.tabMoney,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: sq.live),
              label: l10n.tabRecap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuldok sa pagitan ng dalawang maliit na katotohanan sa app bar.
class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.circle, size: 3, color: context.sq.inkFaint),
    );
  }
}

/// Icon na may maliit na bilang sa balikat.
///
/// Amber ito at hindi tahimik — ito ang tanging bagay sa tab bar na
/// humihingi ng pansin, kaya hindi ito lumalabas kung wala namang dapat
/// gawin.
class _Counted extends StatelessWidget {
  const _Counted({required this.icon, this.count, this.color});

  final IconData icon;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sq = context.sq;
    final glyph = Icon(icon, color: color);
    if (count == null || count == 0) return glyph;

    return Badge(
      backgroundColor: sq.attention,
      textColor: Colors.white,
      textStyle: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: Colors.white, letterSpacing: 0)
          .tabular,
      label: Text('$count'),
      child: glyph,
    );
  }
}
