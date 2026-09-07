import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../models/club_member.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../providers/auth_providers.dart';
import '../providers/session_providers.dart';
import '../providers/sync_error_provider.dart';
import '../services/data_export.dart';
import '../services/money.dart';
import '../services/session_grouping.dart';
import '../widgets/shuttle_mark.dart';
import '../widgets/sync_indicator.dart';
import 'regulars_screen.dart';
import 'session_detail_screen.dart';
import 'session_form_screen.dart';

/// Home ng QM pagkatapos mag-login.
///
/// Isang tanong lang ang dala niya pagbukas: **may laro ba ngayon?** Kaya
/// hindi ito patag na listahan. Ang gabi ngayong araw ay may sariling
/// malaking kard sa itaas; ang iba ay konteksto lang sa ilalim.
class SessionsListScreen extends ConsumerWidget {
  const SessionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      floatingActionButton: _NewSessionButton(onPressed: () => openForm(context)),
      body: SafeArea(
        bottom: false,
        child: sessionsAsync.when(
          loading: () => const _Shell(child: _Loading()),
          // Kahit may error sa network, may cache pa rin karaniwan — huwag
          // takutin ang QM. Ipakita ang empty state at ang New session button.
          error: (_, _) => _Shell(
            child: _EmptyState(onCreate: () => openForm(context)),
          ),
          data: (synced) {
            final grouped = groupSessions(synced.data, DateTime.now());
            return _Shell(
              hasPendingWrites: synced.hasPendingWrites,
              child: grouped.isEmpty
                  ? _EmptyState(onCreate: () => openForm(context))
                  : _SessionList(grouped: grouped),
            );
          },
        ),
      ),
    );
  }

  static void openForm(BuildContext context, {Session? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionFormScreen(existing: existing),
      ),
    );
  }
}

/// Ang berdeng banda sa itaas at ang laman sa ilalim nito.
///
/// Banda at hindi AppBar: dito nakaupo ang pangalan ng QM at ang dalawang
/// bilang na hindi niya makikita kahit saan pa — ilang regular ang nasa
/// libro, at magkano ang dala-dalang utang sa kanya.
class _Shell extends ConsumerWidget {
  const _Shell({required this.child, this.hasPendingWrites = false});

  final Widget child;
  final bool hasPendingWrites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const _Header(),
        SyncIndicator(hasPendingWrites: hasPendingWrites),
        Expanded(child: child),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final user = ref.watch(authStateChangesProvider).value;
    final name = user?.displayName?.trim();
    final members = ref.watch(clubMembersProvider).value ?? const <ClubMember>[];

    // Positibo ang balanse = may utang sa QM. Ito ang perang hindi pa
    // nakokolekta mula noong nakaraang gabi.
    final owed = members.fold<int>(
      0,
      (sum, m) => sum + (m.balanceCentavos > 0 ? m.balanceCentavos : 0),
    );

    return Container(
      width: double.infinity,
      color: scheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShuttleMark(size: 34, color: scheme.onPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (name != null && name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.moreActions,
                icon: Icon(Icons.more_vert, color: scheme.onPrimary),
                onSelected: (value) => switch (value) {
                  'export' => _export(context, ref, l10n),
                  _ => _confirmSignOut(context, ref, l10n),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_outlined),
                      title: Text(l10n.exportAll),
                      subtitle: Text(l10n.exportAllHint),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'signout',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout),
                      title: Text(l10n.signOut),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${members.length}',
                  label: l10n.statRegulars,
                  icon: Icons.badge_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegularsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  value: formatCentavos(owed),
                  label: l10n.statOwed,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegularsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Isinusulat ang buong datos ng QM sa isang JSON file na siya na ang
  /// may hawak.
  ///
  /// Sa libreng tier ng Firestore ay WALANG naka-iskedyul na backup. Ito
  /// ang tanging paraan para may kopya siya sa labas ng Firebase — at ito
  /// rin ang sagot sa karapatan sa data portability ng RA 10173.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.exportWorking)),
    );

    try {
      final clubId = await ref.read(defaultClubIdProvider.future);
      final export = await ref.read(exportRepositoryProvider).gather(
            ownerUid: uid,
            clubId: clubId,
            appVersion: kAppVersion,
          );

      final now = DateTime.now();
      final json = encodeDataExport(export);
      final summary = exportSummary(export);

      // Bilang file muna: iyon ang gusto ng QM — isang bagay na
      // maita-attach sa email o maisi-save sa Drive.
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                utf8.encode(json),
                mimeType: 'application/json',
                name: exportFileName(now),
              ),
            ],
            fileNameOverrides: [exportFileName(now)],
            subject: exportFileName(now),
          ),
        );
      } catch (_) {
        // Hindi lahat ng browser ay marunong mag-share ng file. Mas mabuti
        // nang teksto kaysa walang backup — ito ang buong punto ng feature.
        await SharePlus.instance.share(
          ShareParams(text: json, subject: exportFileName(now)),
        );
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.exportDone(summary))),
        );
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.exportFailed)),
        );
      ref.read(syncErrorProvider.notifier).report(error);
    }
  }

  /// Ang tanging dialog sa buong app maliban sa delete — at may dahilan.
  ///
  /// Ang logout ay mukhang maliit na pindutan sa gilid, pero sa gym na
  /// walang signal, hindi na makakabalik ang QM: kailangan ng network ang
  /// pag-sign-in. Isang maling tap sa gitna ng gabi at wala nang laro.
  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.signOutWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.onPrimary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.grouped});

  final GroupedSessions grouped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tonight = grouped.tonight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
      children: [
        if (tonight != null) _TonightCard(session: tonight),
        if (grouped.upcoming.isNotEmpty) ...[
          _SectionLabel(l10n.sectionUpcoming),
          for (final s in grouped.upcoming) _SessionCard(session: s),
        ],
        if (grouped.earlier.isNotEmpty) ...[
          _SectionLabel(l10n.sectionEarlier),
          for (final s in grouped.earlier) _SessionCard(session: s),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Ang gabi ngayong araw, malaki at may isang malinaw na aksyon.
class _TonightCard extends StatelessWidget {
  const _TonightCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLive = session.status == SessionStatus.live;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isLive) ...[
                    _LiveDot(color: scheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isLive ? l10n.sessionStatusLive : l10n.tonightLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                session.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(session.sessionDate) +
                    (session.venue.isEmpty ? '' : ' · ${session.venue}'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Fact(
                    icon: Icons.grid_view_outlined,
                    label: l10n.courtCountLabel(session.courtCount),
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 16),
                  _Fact(
                    icon: Icons.payments_outlined,
                    label: formatCentavos(session.courtFeeCentavos),
                    color: scheme.onPrimaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _open(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(isLive ? l10n.resumeNight : l10n.openNight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailScreen(sessionId: session.id),
      ),
    );
  }
}

/// Tahimik na tibok — sapat para mapansin, hindi sapat para makaabala.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  // Ginagawa sa initState, HINDI `late final` na may inline na halaga.
  //
  // Ganito ako nadapa: `late final _controller = AnimationController(...)`
  // ay ginagawa lang sa UNANG paggamit. Kapag naka-reduce motion, hindi
  // ito nagagalaw ng build() — kaya ang dispose() na ang unang humipo, at
  // doon ito ginagawa: bumubuo ng ticker sa isang patay nang element.
  // "Looking up a deactivated widget's ancestor is unsafe" — crash sa
  // pag-alis sa dashboard, para lang sa mga taong naka-reduce motion.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dito ligtas basahin ang MediaQuery. Kapag ayaw ng tao ng galaw,
    // pinapatigil natin ang ticker mismo — hindi lang itinatago ang epekto.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    // Tuloy pa rin ang tuldok kapag naka-reduce motion — hindi na lang
    // ito kumikislap. Ang impormasyon ay nananatili; ang galaw lang ang
    // nawawala.
    if (reduceMotion) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: dot,
    );
  }
}

class _NewSessionButton extends StatelessWidget {
  const _NewSessionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(l10n.newSession),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
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
            ShuttleMark(size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 20),
            Text(l10n.sessionsEmptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.sessionsEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.newSession),
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
    final dateText =
        DateFormat('EEE, MMM d · h:mm a').format(session.sessionDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSession(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: session.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (session.venue.isNotEmpty)
                Text(
                  session.venue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Fact(
                    icon: Icons.grid_view_outlined,
                    label: l10n.courtCountLabel(session.courtCount),
                  ),
                  const SizedBox(width: 14),
                  _Fact(
                    icon: Icons.payments_outlined,
                    label: formatCentavos(session.courtFeeCentavos),
                  ),
                  const Spacer(),
                  // Lingguhan ang club — halos pareho na ang lahat ng
                  // detalye ng susunod na gabi, kaya isang tap at petsa
                  // na lang ang kailangan.
                  IconButton(
                    tooltip: l10n.repeatSession,
                    icon: const Icon(Icons.event_repeat_outlined),
                    onPressed: () => _repeat(context),
                  ),
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

  /// Bagong gabi, kopya ng mga detalye nito. Hindi kasama ang roster —
  /// hindi lahat ng dumalo noong isang linggo ay darating ulit, at ang
  /// paste-import kasama ang regulars book ay mabilis na naman.
  void _repeat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionFormScreen(template: session),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: tint.withValues(alpha: 0.75)),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: tint),
        ),
      ],
    );
  }
}
