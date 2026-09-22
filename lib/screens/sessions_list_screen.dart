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
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/shuttle_mark.dart';
import '../widgets/surfaces.dart';
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
      backgroundColor: context.sq.canvas,
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
    final sq = context.sq;

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
      decoration: BoxDecoration(
        color: sq.live,
        // Bilugan ang ibaba: ang banda ay isang bagay na nakapatong sa
        // pahina, hindi hangganan ng screen. Ito rin ang nagsasabing may
        // naka-scroll pa sa ilalim niya.
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(SQRadius.sheet),
        ),
        boxShadow: sq.shadowLifted,
      ),
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.md,
        SQSpace.sm,
        SQSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShuttleMark(size: 32, color: Colors.white),
              const SizedBox(width: SQSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (name != null && name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.moreActions,
                icon: const Icon(Icons.more_vert, color: Colors.white),
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
          const SizedBox(height: SQSpace.lg),
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
              const SizedBox(width: SQSpace.md),
              Expanded(
                child: _StatTile(
                  value: formatCentavos(owed),
                  label: l10n.statOwed,
                  icon: Icons.account_balance_wallet_outlined,
                  // Ang utang ay hindi tahimik kapag may laman: amber ang
                  // numero, kaya nakikita ito bago pa mabasa ang label.
                  highlight: owed > 0,
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
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ang amber sa ibabaw ng berde ay mahina ang kontrast, kaya ang
    // ginagamit dito ay maputlang bersyon nito — nakikitang iba sa puti,
    // at nababasa pa rin sa ilalim ng ilaw ng gym.
    final accent = highlight ? const Color(0xFFFFD79A) : Colors.white;

    return SQPressable(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(SQRadius.lg)),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SQSpace.md,
          vertical: SQSpace.md,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: const BorderRadius.all(Radius.circular(SQRadius.lg)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: SQSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: accent)
                        .scoreboard,
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
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
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.grouped});

  final GroupedSessions grouped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tonight = grouped.tonight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.xl,
        SQSpace.lg,
        104,
      ),
      children: [
        if (tonight != null) _TonightCard(session: tonight),
        if (grouped.upcoming.isNotEmpty) ...[
          _SectionLabel(l10n.sectionUpcoming),
          for (var i = 0; i < grouped.upcoming.length; i++)
            SQEntrance(index: i, child: _SessionCard(session: grouped.upcoming[i])),
        ],
        if (grouped.earlier.isNotEmpty) ...[
          _SectionLabel(l10n.sectionEarlier),
          for (var i = 0; i < grouped.earlier.length; i++)
            SQEntrance(index: i, child: _SessionCard(session: grouped.earlier[i])),
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
      padding: const EdgeInsets.fromLTRB(
        SQSpace.xs,
        SQSpace.xxl,
        SQSpace.xs,
        SQSpace.md,
      ),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.sq.inkFaint,
            ),
          ),
          const SizedBox(width: SQSpace.md),
          Expanded(child: SQHairline()),
        ],
      ),
    );
  }
}

/// Ang gabi ngayong araw, malaki at may isang malinaw na aksyon.
///
/// Ito ang **nag-iisang** bagay sa buong app na may ganitong bigat: puno
/// ng berde, nakaangat, at may sarili nitong malaking pindutan. Kapag may
/// pangalawa, hindi na alam ng mata kung saan titingin muna.
class _TonightCard extends StatelessWidget {
  const _TonightCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;
    final isLive = session.status == SessionStatus.live;

    return SQPressable(
      onTap: () => _open(context),
      scale: 0.99,
      borderRadius: SQRadius.heroShape,
      child: Container(
        padding: const EdgeInsets.all(SQSpace.xl),
        decoration: BoxDecoration(
          color: sq.live,
          borderRadius: SQRadius.heroShape,
          boxShadow: sq.shadowLifted,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ang estado ay tatak sa tabi ng pamagat, hindi maliit na
            // salita sa ibabaw nito. Ang salitang nakapatong sa pamagat ay
            // nagpapahina sa pamagat; ang tatak sa gilid ay nagsasabi ng
            // ibang bagay — kung anong kalagayan ang gabi ngayon.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SQSpace.md),
                _HeroStatus(
                  label: isLive ? l10n.sessionStatusLive : l10n.tonightLabel,
                  live: isLive,
                ),
              ],
            ),
            const SizedBox(height: SQSpace.xs),
            Text(
              DateFormat('h:mm a').format(session.sessionDate) +
                  (session.venue.isEmpty ? '' : ' · ${session.venue}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SQSpace.lg),
            Row(
              children: [
                _Fact(
                  icon: Icons.grid_view_outlined,
                  label: l10n.courtCountLabel(session.courtCount),
                  color: Colors.white,
                ),
                const SizedBox(width: SQSpace.lg),
                _Fact(
                  icon: Icons.payments_outlined,
                  label: formatCentavos(session.courtFeeCentavos),
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: SQSpace.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.white,
                foregroundColor: sq.live,
              ),
              onPressed: () => _open(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(isLive ? l10n.resumeNight : l10n.openNight),
            ),
          ],
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

/// Tatak ng estado sa ibabaw ng berde.
///
/// Sarili nitong hugis at hindi [SQStatusPill]: lahat ng tono ng pill ay
/// madilim sa maputlang likod, at dito ay kabaligtaran. Isang lugar lang
/// ito ginagamit — ang kard ng gabi ngayong araw.
class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SQSpace.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: SQRadius.pill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            SQLivePulse(color: Colors.white, size: 6),
            const SizedBox(width: SQSpace.xs),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
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
    final sq = context.sq;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(SQSpace.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ang marka mismo ang larawan dito — hindi generic na icon.
              // Ito ang unang screen ng bagong QM, at dapat ShuttleQueue
              // ang tingin niya, hindi "isang app".
              ShuttleMark(size: 64, color: sq.line),
              const SizedBox(height: SQSpace.xl),
              Text(
                l10n.sessionsEmptyTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SQSpace.sm),
              Text(
                l10n.sessionsEmptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: sq.inkMuted),
              ),
              const SizedBox(height: SQSpace.xxl),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.newSession),
              ),
            ],
          ),
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
    final sq = context.sq;
    final dateText =
        DateFormat('EEE, MMM d · h:mm a').format(session.sessionDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: SQSpace.sm),
      child: SQPressable(
        onTap: () => _openSession(context),
        child: SQCard(
          tone: session.status == SessionStatus.live
              ? SQTone.live
              : SQTone.neutral,
          padding: const EdgeInsets.fromLTRB(
            SQSpace.lg,
            SQSpace.md,
            SQSpace.sm,
            SQSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: SQSpace.sm),
                  _StatusChip(status: session.status),
                ],
              ),
              const SizedBox(height: SQSpace.xs),
              Text(
                dateText,
                style: theme.textTheme.bodySmall?.copyWith(color: sq.inkMuted),
              ),
              if (session.venue.isNotEmpty)
                Text(
                  session.venue,
                  style: theme.textTheme.bodySmall?.copyWith(color: sq.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: SQSpace.sm),
              Row(
                children: [
                  _Fact(
                    icon: Icons.grid_view_outlined,
                    label: l10n.courtCountLabel(session.courtCount),
                  ),
                  const SizedBox(width: SQSpace.lg),
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
                    icon: Icon(Icons.event_repeat_outlined, color: sq.inkFaint),
                    onPressed: () => _repeat(context),
                  ),
                  IconButton(
                    tooltip: l10n.deleteSession,
                    icon: Icon(Icons.delete_outline, color: sq.inkFaint),
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
    final sq = context.sq;

    return switch (status) {
      SessionStatus.setup =>
        SQStatusPill(label: l10n.sessionStatusSetup, dense: true),
      SessionStatus.live => SQStatusPill(
          label: l10n.sessionStatusLive,
          tone: SQTone.live,
          dense: true,
          leading: SQLivePulse(color: sq.live, size: 6),
        ),
      SessionStatus.ended =>
        SQStatusPill(label: l10n.sessionStatusEnded, dense: true),
    };
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
    final tint = color ?? context.sq.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tint.withValues(alpha: 0.75)),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: tint).tabular,
        ),
      ],
    );
  }
}
