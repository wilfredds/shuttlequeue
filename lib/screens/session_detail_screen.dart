import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/session_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider(widget.sessionId)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.title ?? l10n.appTitle),
        actions: [
          if (session != null)
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
