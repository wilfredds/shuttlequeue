import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/session_providers.dart';
import '../services/session_snapshot.dart';
import 'board_screen.dart';
import 'cost_split_screen.dart';
import 'courts_screen.dart';
import 'roster_screen.dart';
import 'session_form_screen.dart';

/// Ang bahay ng QM sa loob ng isang gabi. Tatlong tab lang — sinasadya:
/// sino ang nandito, sino ang naglalaro, magkano ang bayad.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider(widget.sessionId)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.title ?? l10n.appTitle),
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
          ],
        ],
      ),
      body: switch (_tabIndex) {
        0 => RosterScreen(sessionId: widget.sessionId),
        1 => CourtsScreen(sessionId: widget.sessionId),
        _ => CostSplitScreen(sessionId: widget.sessionId),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.tabRoster,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: l10n.tabCourts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: l10n.tabMoney,
          ),
        ],
      ),
    );
  }
}
