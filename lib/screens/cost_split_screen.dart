import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/bill_line.dart';
import '../models/club.dart';
import '../models/session.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../services/fee_calculator.dart';
import '../services/money.dart';

/// Ang dulo ng gabi: sino ang may bayad, magkano, at sino pa ang hindi.
class CostSplitScreen extends ConsumerWidget {
  const CostSplitScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final session = ref.watch(sessionProvider(sessionId)).value;
    final players =
        ref.watch(playersProvider(sessionId)).value?.data ?? const [];

    if (session == null || players.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.moneyEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    final frozen = ref.watch(billProvider(sessionId)).value ?? const <BillLine>[];

    // R-09: kapag naka-lock, ang naka-imbak na halaga ang totoo. Ang live
    // na kuwenta ay ginagamit lang bago mag-lock.
    final breakdown = session.isBillFinalized && frozen.isNotEmpty
        ? _frozenBreakdown(frozen, players, session.feeMode)
        : const FeeCalculator().calculate(
            players: players,
            courtFeeCentavos: session.courtFeeCentavos,
            shuttlePriceCentavos: session.shuttlePriceCentavos,
            feeMode: session.feeMode,
          );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _Summary(breakdown: breakdown),
          const SizedBox(height: 10),
          _LockBanner(sessionId: sessionId, session: session,
              breakdown: breakdown),
          const SizedBox(height: 6),
          const _GcashCard(),
          const SizedBox(height: 6),
          for (final line in breakdown.lines)
            _FeeTile(
              sessionId: sessionId,
              line: line,
              feeMode: session.feeMode,
              isLocked: session.isBillFinalized,
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Utang: dinadala sa susunod na gabi ang hindi nabayaran.
          // Ganito talaga tumatakbo ang mga club — nasa memorya ng QM at
          // sa notebook ang listahang ito ngayon.
          FloatingActionButton.small(
            heroTag: 'carry',
            tooltip: l10n.carryUnpaid,
            onPressed: () => _carryUnpaid(context, ref, breakdown, players),
            child: const Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'shareFees',
            onPressed: () =>
                _share(context, session, breakdown, ref.read(clubProvider).value),
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.shareSummary),
          ),
        ],
      ),
    );
  }

  /// Binubuo muli ang breakdown mula sa mga naka-freeze na halaga.
  /// Ang `hasPaid` ay kinukuha pa rin sa player doc — tuloy ang koleksyon,
  /// ang presyo lang ang hindi na gumagalaw.
  FeeBreakdown _frozenBreakdown(
    List<BillLine> frozen,
    List<SessionPlayer> players,
    FeeMode mode,
  ) {
    final playersById = {for (final p in players) p.id: p};
    final lines = <FeeLine>[];

    for (final line in frozen) {
      final player = playersById[line.playerId];
      lines.add(
        FeeLine(
          playerId: line.playerId,
          name: line.name,
          courtShareCentavos: line.courtShareCentavos,
          shuttleShareCentavos: line.shuttleShareCentavos,
          hasPaid: player?.hasPaid ?? false,
          hasLeft: player?.status == PlayerStatus.left,
        ),
      );
    }
    lines.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final total = lines.fold(0, (sum, l) => sum + l.totalCentavos);
    return FeeBreakdown(
      lines: lines,
      mode: mode,
      expectedTotalCentavos: total,
    );
  }

  /// Dinadala ang hindi nabayaran sa regulars book, para lumabas ito sa
  /// susunod na gabi. Ang mga bisita (walang memberId) ay hindi kasama —
  /// walang record na babalikan para sa kanila.
  Future<void> _carryUnpaid(
    BuildContext context,
    WidgetRef ref,
    FeeBreakdown breakdown,
    List<SessionPlayer> players,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final clubId = ref.read(defaultClubIdProvider).value;
    if (clubId == null) return;

    final memberIdOf = {
      for (final p in players)
        if (p.memberId != null) p.id: p.memberId!,
    };

    final clubRepo = ref.read(clubRepositoryProvider);
    final playerRepo = ref.read(playerRepositoryProvider);
    var carried = 0;

    for (final line in breakdown.lines) {
      if (line.hasPaid) continue;
      final memberId = memberIdOf[line.playerId];
      if (memberId == null) continue;

      await clubRepo.adjustBalance(clubId, memberId, line.totalCentavos);
      // Markahang bayad na sa gabing ito: nailipat na ang utang sa
      // regulars book, kaya hindi na ito dapat bilangin nang dalawang beses.
      await playerRepo.updatePlayer(sessionId, line.playerId, hasPaid: true);
      carried++;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          carried == 0 ? l10n.carryUnpaidNone : l10n.carryUnpaidDone(carried),
        ),
      ),
    );
  }

  /// Plain text na madaling i-paste pabalik sa Messenger group — doon
  /// nakatira ang usapan ng grupo, hindi dito.
  Future<void> _share(
    BuildContext context,
    Session session,
    FeeBreakdown breakdown,
    Club? gcash,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final date = DateFormat('EEE, MMM d, y').format(session.sessionDate);

    final buffer = StringBuffer()
      ..writeln(session.title)
      ..writeln(date)
      ..writeln(session.venue)
      ..writeln();

    for (final line in breakdown.lines) {
      final mark = line.hasPaid ? '✅' : '—';
      buffer.writeln(
        '$mark ${line.name}: ${formatCentavos(line.totalCentavos)}',
      );
    }

    if (gcash != null && gcash.hasGcash) {
      buffer
        ..writeln()
        ..writeln('${l10n.gcashTitle}: ${gcash.formattedGcash}');
    }

    buffer
      ..writeln()
      ..writeln('${l10n.totalCost}: '
          '${formatCentavos(breakdown.chargedTotalCentavos)}')
      ..writeln('${l10n.collected}: '
          '${formatCentavos(breakdown.collectedCentavos)}')
      ..writeln('${l10n.outstanding}: '
          '${formatCentavos(breakdown.outstandingCentavos)}');

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: session.title),
    );
  }
}

/// Saan ipapadala ng mga manlalaro ang bayad.
///
/// Sinasadyang hindi naka-hardcode ang numero: iba ang numero ng bawat QM,
/// at kapag ang coach na ang humawak ng app, sa KANYA dapat mapunta ang
/// pera — hindi sa gumawa ng app. Isang beses lang itong ita-type.
class _GcashCard extends ConsumerWidget {
  const _GcashCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final club = ref.watch(clubProvider).value;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _edit(context, ref, club),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gcashTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      club != null && club.hasGcash
                          ? club.formattedGcash
                          : l10n.gcashAdd,
                      style: theme.textTheme.titleMedium?.copyWith(
                        // Malaki at madaling basahin — babasahin ito ng
                        // manlalaro mula sa kabilang dulo ng mesa.
                        fontWeight: FontWeight.w700,
                        color: club != null && club.hasGcash
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Club? club) async {
    final l10n = AppLocalizations.of(context)!;
    final clubId = ref.read(defaultClubIdProvider).value;
    if (clubId == null) return;

    final controller = TextEditingController(text: club?.gcashNumber ?? '');
    String? errorText;

    final saved = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.gcashEdit),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.gcashNumberLabel,
                  hintText: '0929 365 6299',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.gcashHint,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                // Blangko = tanggalin ang numero.
                if (raw.isEmpty) {
                  Navigator.of(dialogContext).pop('');
                  return;
                }
                final normalized = normalizeGcashNumber(raw);
                if (normalized == null) {
                  setState(() => errorText = l10n.gcashInvalid);
                  return;
                }
                Navigator.of(dialogContext).pop(normalized);
              },
              child: Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (saved == null) return;

    await ref
        .read(clubRepositoryProvider)
        .setGcashNumber(clubId, saved.isEmpty ? null : saved);
  }
}

/// Ang kontrol para sa pag-freeze ng bayarin (R-09).
class _LockBanner extends ConsumerWidget {
  const _LockBanner({
    required this.sessionId,
    required this.session,
    required this.breakdown,
  });

  final String sessionId;
  final Session session;
  final FeeBreakdown breakdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!session.isBillFinalized) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.billNotLockedHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: breakdown.lines.isEmpty
                    ? null
                    : () => _lock(ref),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(l10n.finalizeBill),
              ),
            ],
          ),
        ),
      );
    }

    final lockedAt = DateFormat('h:mm a').format(session.billFinalizedAt!);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Icon(Icons.lock, size: 18,
                color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.billLocked,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    l10n.billLockedAt(lockedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _confirmReopen(context, ref, l10n),
              child: Text(l10n.reopenBill),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lock(WidgetRef ref) async {
    final lines = [
      for (final line in breakdown.lines)
        BillLine(
          playerId: line.playerId,
          name: line.name,
          courtShareCentavos: line.courtShareCentavos,
          shuttleShareCentavos: line.shuttleShareCentavos,
        ),
    ];
    await ref.read(sessionRepositoryProvider).finalizeBill(sessionId, lines);
  }

  /// Ang pag-unlock ay may kumpirmasyon — hindi tulad ng mga aksyon sa
  /// gitna ng laro. Dito, ang mali ay pera: baka may nabayaran na pala na
  /// hindi na tugma sa bagong kuwenta.
  Future<void> _confirmReopen(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reopenBillTitle),
        content: Text(l10n.reopenBillWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reopenBillCta),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(sessionRepositoryProvider).reopenBill(sessionId);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.breakdown});

  final FeeBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatCentavos(breakdown.chargedTotalCentavos),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              l10n.totalCost,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Metric(
                  label: l10n.collected,
                  value: formatCentavos(breakdown.collectedCentavos),
                ),
                const SizedBox(width: 24),
                _Metric(
                  label: l10n.outstanding,
                  value: formatCentavos(breakdown.outstandingCentavos),
                ),
                const Spacer(),
                Text(
                  l10n.paidOf(breakdown.paidCount, breakdown.lines.length),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
        ),
      ],
    );
  }
}

class _FeeTile extends ConsumerWidget {
  const _FeeTile({
    required this.sessionId,
    required this.line,
    required this.feeMode,
    required this.isLocked,
  });

  final String sessionId;
  final FeeLine line;
  final FeeMode feeMode;

  /// Naka-lock na ang halaga: itinatago ang shuttle stepper dahil hindi na
  /// nito mababago ang singil, at nakakalito kung mukhang kaya pa.
  final bool isLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = ref.read(playerRepositoryProvider);

    final shuttles = feeMode == FeeMode.perHead && line.shuttleShareCentavos > 0
        ? ' · ${formatCentavos(line.shuttleShareCentavos)} ${l10n.shuttlesLabel.toLowerCase()}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          line.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (line.hasLeft)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            l10n.leftEarlyTag,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${formatCentavos(line.totalCentavos)}$shuttles',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Bilang ng shuttle — stepper, para hindi mag-type ang QM.
            if (feeMode == FeeMode.perHead && !isLocked) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () =>
                    repo.adjustShuttles(sessionId, line.playerId, -1),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () =>
                    repo.adjustShuttles(sessionId, line.playerId, 1),
              ),
            ],

            // Malaking target: ito ang pinipindot habang tumatanggap ng bayad.
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: FilterChip(
                selected: line.hasPaid,
                label: Text(l10n.markPaid),
                onSelected: (value) => repo.updatePlayer(
                  sessionId,
                  line.playerId,
                  hasPaid: value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
