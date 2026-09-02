import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../providers/auth_providers.dart';
import '../providers/session_providers.dart';
import '../services/money.dart';
import '../widgets/sync_indicator.dart';
import 'session_detail_screen.dart';
import 'session_form_screen.dart';

/// Home ng QM pagkatapos mag-login: listahan ng mga gabi.
class SessionsListScreen extends ConsumerWidget {
  const SessionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsTitle),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newSession),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Kahit may error sa network, may cache pa rin karaniwan — huwag
        // takutin ang QM. Ipakita ang empty state at ang New session button.
        error: (_, _) => _EmptyState(onCreate: () => _openForm(context)),
        data: (synced) {
          final sessions = synced.data;
          return Column(
            children: [
              SyncIndicator(hasPendingWrites: synced.hasPendingWrites),
              Expanded(
                child: sessions.isEmpty
                    ? _EmptyState(onCreate: () => _openForm(context))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) =>
                            _SessionCard(session: sessions[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, {Session? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionFormScreen(existing: existing),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

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
              Icons.event_note_outlined,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(l10n.sessionsEmptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.sessionsEmptyBody,
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

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateText = DateFormat('EEE, MMM d · h:mm a').format(session.sessionDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSession(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: session.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (session.venue.isNotEmpty)
                Text(
                  session.venue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Fact(
                    icon: Icons.sports_tennis,
                    label: l10n.courtCountLabel(session.courtCount),
                  ),
                  const SizedBox(width: 16),
                  _Fact(
                    icon: Icons.payments_outlined,
                    label: formatCentavos(session.courtFeeCentavos),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.deleteSession,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, l10n),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSession(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailScreen(sessionId: session.id),
      ),
    );
  }

  /// Ang session delete ay **cascade** — kasama ang players, courts at
  /// matches. Hindi ito maibabalik ng undo (wala nang dokumentong babalikan),
  /// kaya dito tayo humihingi ng kumpirmasyon. Ang mga aksyon sa loob ng
  /// gabi ay undo-able — walang dialog doon (R-15).
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteSession),
        content: Text(l10n.deleteSessionConfirm(session.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteSessionCta),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(sessionRepositoryProvider).deleteSession(session.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.sessionDeleted)));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final (String label, Color background, Color foreground) = switch (status) {
      SessionStatus.setup => (
          l10n.sessionStatusSetup,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      SessionStatus.live => (
          l10n.sessionStatusLive,
          scheme.primary,
          scheme.onPrimary,
        ),
      SessionStatus.ended => (
          l10n.sessionStatusEnded,
          scheme.surfaceContainerHighest,
          scheme.outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
