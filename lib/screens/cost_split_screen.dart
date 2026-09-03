import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
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

    final breakdown = const FeeCalculator().calculate(
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
          const SizedBox(height: 12),
          for (final line in breakdown.lines)
            _FeeTile(
              sessionId: sessionId,
              line: line,
              feeMode: session.feeMode,
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
            onPressed: () => _share(context, session, breakdown),
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.shareSummary),
          ),
        ],
      ),
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
  });

  final String sessionId;
  final FeeLine line;
  final FeeMode feeMode;

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
            if (feeMode == FeeMode.perHead) ...[
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
