import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/bill_line.dart';
import '../models/club.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../models/session_player.dart';
import '../providers/session_providers.dart';
import '../services/bill_share.dart';
import '../services/fee_calculator.dart';
import '../services/money.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/player_avatar.dart';
import '../widgets/surfaces.dart';

/// Ang dulo ng gabi: sino ang may bayad, magkano, at sino pa ang hindi.
///
/// ITO ANG SCREEN NA PINAKAMABILIS SUMIRA NG TIWALA. Ang bawat ibang
/// screen ay tungkol sa laro; ito ay tungkol sa pera ng ibang tao. Kaya:
///
///  * **Isang bilang ang nangingibabaw** — kung magkano ang hatian kada
///    tao. Iyon ang tanong na tinatanong nang labindalawang beses kada
///    gabi, at dati ay kailangan pang basahin sa isang listahan.
///  * **May guhit ng pag-usad ang koleksyon.** Hindi ito palamuti: ito
///    ang sagot sa "tapos na ba ako?" nang hindi binibilang ang mga tsek.
///  * **Ang buong hilera ay pindutan.** Isang kamay lang ang libre ng QM
///    habang tumatanggap ng pera; hindi siya dapat tumutudla ng maliit na
///    chip.
class CostSplitScreen extends ConsumerWidget {
  const CostSplitScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final session = ref.watch(sessionProvider(sessionId)).value;
    final players =
        ref.watch(playersProvider(sessionId)).value?.data ?? const [];

    if (session == null || players.isEmpty) {
      return Scaffold(
        backgroundColor: context.sq.canvas,
        body: SQEmptyState(
          icon: Icons.payments_outlined,
          title: l10n.moneyTitle,
          body: l10n.moneyEmpty,
        ),
      );
    }

    final frozen = ref.watch(billProvider(sessionId)).value ?? const <BillLine>[];

    // Ang mukha ay buhay kahit naka-lock ang bill: ang naka-freeze ay ang
    // HALAGA, hindi kung ano ang hitsura ng tao.
    final seedById = {for (final p in players) p.id: p.avatarSeed};
    final shuttlesById = {for (final p in players) p.id: p.shuttlesUsed};

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
      backgroundColor: context.sq.canvas,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: SQSpace.xxl),
              children: [
                _BillHeader(breakdown: breakdown),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SQSpace.lg,
                    SQSpace.lg,
                    SQSpace.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LockBanner(
                        sessionId: sessionId,
                        session: session,
                        breakdown: breakdown,
                      ),
                      const SizedBox(height: SQSpace.md),
                      const _GcashCard(),
                      const SizedBox(height: SQSpace.xl),
                      for (var i = 0; i < breakdown.lines.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: SQSpace.sm),
                          child: SQEntrance(
                            index: i,
                            child: _FeeTile(
                              sessionId: sessionId,
                              line: breakdown.lines[i],
                              feeMode: session.feeMode,
                              isLocked: session.isBillFinalized,
                              avatarSeed: seedById[breakdown.lines[i].playerId],
                              shuttlesUsed:
                                  shuttlesById[breakdown.lines[i].playerId] ?? 0,
                            ),
                          ),
                        ),
                      const SizedBox(height: SQSpace.lg),
                      // Nasa DULO ng listahan ang paglipat ng utang, hindi
                      // sa nakapinid na bar: dito lumalapag ang QM kapag
                      // tapos na siyang mangolekta, at dito lang ito may
                      // saysay.
                      OutlinedButton.icon(
                        onPressed: () =>
                            _carryUnpaid(context, ref, breakdown, players),
                        icon: const Icon(Icons.receipt_long_outlined, size: 19),
                        label: Text(l10n.carryUnpaid),
                      ),
                      const SizedBox(height: SQSpace.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Nasa bar ang dalawang aksyon ng dulo ng gabi, hindi sa
          // magkapatong na FAB. Sa listahan ng labindalawang pangalan,
          // natatakpan ng lumulutang na pindutan ang mismong hilerang
          // pinipindot habang tumatanggap ng bayad.
          SQCommandBar(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _share(
                  context,
                  session,
                  breakdown,
                  ref.read(clubProvider).value,
                ),
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.shareSummary),
              ),
            ),
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
          // Ang bilang ay galing sa naka-freeze na linya, HINDI sa player
          // doc. Kung sa player doc natin ito kukunin, ang isang larong
          // naipuslit pagkatapos ng lock ay gagawing "9 games" ang hilera
          // na may bayad para sa walo — at ang hindi pagkakatugmang iyon
          // ang eksaktong bagay na pinipigilan ng lock.
          gamesPlayed: line.gamesPlayed,
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
      // Mula rin sa mga naka-freeze na linya ang dalawang ito, kaya ang
      // ipinapakitang halaga kada laro ay tugma sa mga halagang nakalista
      // sa ibaba nito — kahit magpatuloy pa ang laro pagkatapos ng lock.
      courtFeeCentavos: lines.fold(0, (sum, l) => sum + l.courtShareCentavos),
      totalPlayerGames: lines.fold(0, (sum, l) => sum + l.gamesPlayed),
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

    // Sa per-game, ang listahan ay may magkakaibang halaga. Isang linya sa
    // itaas ang nagpapaliwanag ng lahat ng iyon, at ang bilang ng laro ang
    // nasa tabi ng bawat pangalan — kung hindi, ang teksto sa group chat ay
    // mukhang pagkakamali at ang QM ang sasagot ng labindalawang tanong.
    final perGame = breakdown.mode == FeeMode.perGame &&
        breakdown.totalPlayerGames > 0;

    final text = buildBillShareText(
      title: session.title,
      dateLabel: date,
      venue: session.venue,
      breakdown: breakdown,
      gcashTitle: l10n.gcashTitle,
      gcashNumber:
          gcash != null && gcash.hasGcash ? gcash.formattedGcash : null,
      totalLabel: l10n.totalCost,
      collectedLabel: l10n.collected,
      outstandingLabel: l10n.outstanding,
      gamesLabel: perGame ? l10n.gamesPlayedShort : null,
      basisLine: perGame
          ? '${l10n.moneyPerGameRate(
              formatCentavos(breakdown.courtRatePerGameCentavos),
            )} · ${l10n.moneyPerGameBasis(
              formatCentavos(breakdown.courtFeeCentavos),
              breakdown.totalPlayerGames,
            )}'
          : null,
    );

    await SharePlus.instance.share(
      ShareParams(text: text, subject: session.title),
    );
  }
}

/// Ang ulo ng bill: magkano kada tao, at gaano na kalayo ang koleksyon.
///
/// Buong lapad ito at puti, hindi kard na lumulutang — kaya ito ang
/// *papel*, at ang mga hilera sa ibaba ang nakasulat dito. Isang hugis
/// lang ito sa buong app, at dito lang.
class _BillHeader extends StatelessWidget {
  const _BillHeader({required this.breakdown});

  final FeeBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;

    final lines = breakdown.lines;
    final total = breakdown.chargedTotalCentavos;
    final collected = breakdown.collectedCentavos;
    final progress = total == 0 ? 0.0 : (collected / total).clamp(0.0, 1.0);
    final done = lines.isNotEmpty && breakdown.paidCount == lines.length;

    // Ang pinakamadalas na tanong sa gabi ay hindi "magkano lahat" kundi
    // "magkano ako". Kapag pare-pareho ang hati, iyon ang nasa itaas.
    final shares = lines.map((l) => l.totalCentavos).toSet();

    // Sa per-game, walang iisang "magkano ako" — iba-iba ang bayad. Ang
    // tanong na tinatanong nang labindalawang beses ay naging "magkano
    // kada laro", at iyon ang nasasagot nang isang beses sa buong grupo.
    // Kaya iyon ang nangingibabaw na bilang dito, hindi ang kabuuan.
    final perGame = breakdown.mode == FeeMode.perGame &&
        breakdown.totalPlayerGames > 0;

    final String headline;
    final String headlineLabel;
    if (perGame) {
      headline = formatCentavos(breakdown.courtRatePerGameCentavos);
      headlineLabel = l10n.moneyPerGameRateLabel;
    } else if (shares.length == 1) {
      headline = formatCentavos(shares.first);
      headlineLabel = l10n.perPlayerLabel;
    } else {
      headline = formatCentavos(total);
      headlineLabel = l10n.totalCost;
    }

    // Kapag hindi tugma ang nangingibabaw na bilang sa kabuuan, kailangang
    // makita pa rin ang kabuuan sa ibaba — ito ang halagang ipapasa ng QM
    // sa may-ari ng court.
    final showTotalBelow = perGame || shares.length == 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.lg,
        SQSpace.lg,
        SQSpace.lg,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: sq.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: sq.ink,
                        fontSize: 40,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headlineLabel,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: sq.inkMuted),
                    ),
                    // Kung saan nanggaling ang bilang sa itaas. Walang ito,
                    // ang magkakaibang halaga sa listahan ay mukhang
                    // arbitraryo — at ang bill na hindi maipaliwanag ay
                    // hindi babayaran nang walang tanong.
                    if (perGame)
                      Text(
                        l10n.moneyPerGameBasis(
                          formatCentavos(breakdown.courtFeeCentavos),
                          breakdown.totalPlayerGames,
                        ),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: sq.inkFaint)
                            .tabular,
                      ),
                  ],
                ),
              ),
              SQStatusPill(
                label: l10n.paidOf(breakdown.paidCount, lines.length),
                tone: done ? SQTone.live : SQTone.neutral,
                icon: done ? Icons.check_circle_outline : null,
              ),
            ],
          ),
          const SizedBox(height: SQSpace.lg),

          // Ang guhit ng koleksyon. Ito ang sagot sa "tapos na ba?" nang
          // hindi binibilang ang mga tsek — at gumagalaw ito tuwing may
          // nagbabayad, kaya may nararamdamang usad ang QM.
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(SQRadius.sm)),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: progress, end: progress),
              duration: context.motion(SQDuration.count),
              curve: SQCurve.enter,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: sq.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(sq.live),
              ),
            ),
          ),
          const SizedBox(height: SQSpace.md),
          Row(
            children: [
              _Amount(
                label: l10n.collected,
                centavos: collected,
                tone: SQTone.live,
              ),
              const SizedBox(width: SQSpace.xxl),
              _Amount(
                label: l10n.outstanding,
                centavos: breakdown.outstandingCentavos,
                tone: breakdown.outstandingCentavos > 0
                    ? SQTone.attention
                    : SQTone.neutral,
              ),
              const Spacer(),
              if (showTotalBelow)
                _Amount(
                  label: l10n.totalCost,
                  centavos: total,
                  tone: SQTone.neutral,
                  alignEnd: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Halaga ng pera na umaakyat papunta sa bagong bilang.
class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.centavos,
    required this.tone,
    this.alignEnd = false,
  });

  final String label;
  final int centavos;
  final SQTone tone;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sq = context.sq;
    final color =
        tone == SQTone.neutral ? sq.inkStrong : toneColors(context, tone).foreground;

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SQCountUp(
          value: centavos,
          builder: (context, value) => Text(
            // Sentimo pa rin ang binibilang habang umaakyat — hindi
            // kailanman double ang pera, kahit sa animasyon.
            formatCentavos(value.round()),
            style: theme.textTheme.titleMedium?.copyWith(color: color).tabular,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: sq.inkFaint),
        ),
      ],
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
    final sq = context.sq;
    final club = ref.watch(clubProvider).value;
    final hasNumber = club != null && club.hasGcash;

    return SQCard(
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.md,
        SQSpace.sm,
        SQSpace.md,
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 20,
            color: sq.inkMuted,
          ),
          const SizedBox(width: SQSpace.md),
          Expanded(
            child: SQPressable(
              onTap: () => _edit(context, ref, club),
              borderRadius: const BorderRadius.all(
                Radius.circular(SQRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.gcashTitle,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: sq.inkFaint),
                  ),
                  Text(
                    hasNumber ? club.formattedGcash : l10n.gcashAdd,
                    // Malaki at madaling basahin — babasahin ito ng
                    // manlalaro mula sa kabilang dulo ng mesa.
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: hasNumber ? sq.ink : sq.inkFaint)
                        .tabular,
                  ),
                ],
              ),
            ),
          ),
          // Kinokopya, hindi binabasa nang malakas. Sa maingay na gym, ang
          // pagsigaw ng labing-isang numero ay tatlong beses na inuulit.
          if (hasNumber)
            IconButton(
              tooltip: l10n.gcashTitle,
              icon: Icon(Icons.copy_rounded, size: 18, color: sq.inkMuted),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(
                  ClipboardData(text: club.formattedGcash),
                );
                HapticFeedback.selectionClick();
                messenger.showSnackBar(
                  SnackBar(content: Text(club.formattedGcash)),
                );
              },
            )
          else
            Icon(Icons.edit_outlined, size: 18, color: sq.inkFaint),
        ],
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
                // Inaalis ang pulang error sa sandaling magsimulang itama
                // ng QM — nakakalito ang babalang nakadikit sa tamang input.
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
                decoration: InputDecoration(
                  labelText: l10n.gcashNumberLabel,
                  hintText: '0929 365 6299',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: SQSpace.sm),
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
    final sq = context.sq;

    if (!session.isBillFinalized) {
      return SQCard(
        // Nakasalansan, hindi magkatabi. Ang tema ay nagtatakda ng 56dp
        // na taas at 17pt na teksto sa mga pangunahing button — tama iyon
        // para sa isang taong nakatayo sa gilid ng court, pero ang ibig
        // sabihin ay hindi kayang lumiit ng button na ito. Sa 390pt na
        // telepono ay umaapaw ito nang 28 pixel noon, at ang lumalabas ay
        // guhit-guhit na dilaw at itim.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.billNotLockedHint,
              style: theme.textTheme.bodySmall?.copyWith(color: sq.inkMuted),
            ),
            const SizedBox(height: SQSpace.md),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: sq.liveWash,
                foregroundColor: sq.live,
              ),
              onPressed: breakdown.lines.isEmpty ? null : () => _lock(ref),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(l10n.finalizeBill),
            ),
          ],
        ),
      );
    }

    final lockedAt = DateFormat('h:mm a').format(session.billFinalizedAt!);
    return SQCard(
      tone: SQTone.live,
      filled: true,
      padding: const EdgeInsets.fromLTRB(
        SQSpace.lg,
        SQSpace.md,
        SQSpace.sm,
        SQSpace.md,
      ),
      child: Row(
        children: [
          Icon(Icons.lock, size: 18, color: sq.live),
          const SizedBox(width: SQSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.billLocked,
                  style: theme.textTheme.bodyMedium?.copyWith(color: sq.live),
                ),
                Text(
                  l10n.billLockedAt(lockedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sq.live.withValues(alpha: 0.75),
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
          gamesPlayed: line.gamesPlayed,
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
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

class _FeeTile extends ConsumerWidget {
  const _FeeTile({
    required this.sessionId,
    required this.line,
    required this.feeMode,
    required this.isLocked,
    this.avatarSeed,
    this.shuttlesUsed = 0,
  });

  final String sessionId;
  final FeeLine line;
  final FeeMode feeMode;

  /// Hiwalay sa [line] dahil ang mukha ay HINDI pera. Ang FeeCalculator ay
  /// may isang trabaho at ang lahat ng laman ng FeeLine ay nasasagot ng
  /// tanong na "magkano" — manatili sanang ganoon.
  final int? avatarSeed;

  /// Bilang ng shuttle, hiwalay sa halaga nito sa [line] sa parehong
  /// dahilan. Kailangan ito ng stepper para malaman kung nasa zero na.
  final int shuttlesUsed;

  /// Naka-lock na ang halaga: itinatago ang shuttle stepper dahil hindi na
  /// nito mababago ang singil, at nakakalito kung mukhang kaya pa.
  final bool isLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sq = context.sq;
    final repo = ref.read(playerRepositoryProvider);
    final paid = line.hasPaid;

    final showStepper = feeMode.chargesShuttlesIndividually && !isLocked;

    // Ang pangalawang linya ay ang paliwanag ng halaga sa kanan. Sa
    // per-game, ang bilang ng laro ang unang dahilan kung bakit ₱160 ang
    // isa at ₱60 ang katabi — kaya iyon ang nauuna sa shuttle.
    final reasons = <String>[
      if (feeMode == FeeMode.perGame) l10n.gamesPlayedShort(line.gamesPlayed),
      if (feeMode.chargesShuttlesIndividually &&
          line.shuttleShareCentavos > 0)
        '${formatCentavos(line.shuttleShareCentavos)} '
            '${l10n.shuttlesLabel.toLowerCase()}',
    ];
    final shuttles = reasons.isEmpty ? null : reasons.join(' · ');

    return SQPressable(
      // Buong hilera ang target. Isang kamay ang hawak ng pera, ang isa ay
      // ang telepono — walang natitirang daliri para sa maliit na chip.
      onTap: () =>
          repo.updatePlayer(sessionId, line.playerId, hasPaid: !paid),
      haptic: HapticLevel.impact,
      semanticLabel: '${line.name} ${formatCentavos(line.totalCentavos)}',
      child: SQCard(
        tone: paid ? SQTone.live : SQTone.neutral,
        filled: paid,
        padding: EdgeInsets.fromLTRB(
          SQSpace.lg,
          SQSpace.sm,
          showStepper ? SQSpace.xs : SQSpace.md,
          SQSpace.sm,
        ),
        child: Row(
          children: [
            _PaidMark(paid: paid),
            const SizedBox(width: SQSpace.sm),
            // Ang QM ay nakatingin sa TAO, tapos naghahanap ng hilera.
            // Ang mukha ang tumutulay sa dalawa — ito ang screen kung saan
            // pinakamalaki ang halaga niyan, dahil labindalawang pangalan
            // ang binabasa habang may hawak na pera.
            PlayerAvatar(
              name: line.name,
              seed: avatarSeed,
              size: 26,
            ),
            const SizedBox(width: SQSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          line.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: paid ? sq.live : sq.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (line.hasLeft)
                        Padding(
                          padding: const EdgeInsets.only(left: SQSpace.sm),
                          child: Text(
                            l10n.leftEarlyTag,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: sq.inkFaint),
                          ),
                        ),
                    ],
                  ),
                  if (shuttles != null)
                    Text(
                      shuttles,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: sq.inkMuted)
                          .tabular,
                    ),
                ],
              ),
            ),
            Text(
              formatCentavos(line.totalCentavos),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: paid ? sq.live : sq.ink)
                  .tabular,
            ),

            // Bilang ng shuttle — stepper, para hindi mag-type ang QM.
            if (showStepper) ...[
              const SizedBox(width: SQSpace.xs),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: shuttlesUsed > 0 ? sq.inkFaint : sq.line,
                ),
                // WALANG NEGATIBONG SHUTTLE. Tinatanggihan ito ng rules
                // (isCount >= 0), at ang pagtanggi ay dumarating bilang
                // sync-error sa gitna ng pangongolekta — para sa pindutang
                // mukhang pwedeng pindutin. Mas mabuting patay ang pindutan
                // kaysa pindutang nabibigo.
                onPressed: shuttlesUsed > 0
                    ? () => repo.adjustShuttles(sessionId, line.playerId, -1)
                    : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add_circle_outline, color: sq.inkMuted),
                onPressed: () =>
                    repo.adjustShuttles(sessionId, line.playerId, 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ang tsek na pumapasok kapag may nagbayad.
///
/// Lumalaki ito paloob sa halip na biglang sumulpot: ang pagbabago ng
/// pera ay dapat may kaunting timbang, kahit isang-katlong segundo lang.
class _PaidMark extends StatelessWidget {
  const _PaidMark({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final sq = context.sq;

    return AnimatedContainer(
      duration: context.motion(SQDuration.state),
      curve: SQCurve.arrive,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: paid ? sq.live : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: paid ? sq.live : sq.line,
          width: paid ? 1 : 1.8,
        ),
      ),
      child: AnimatedScale(
        scale: paid ? 1 : 0.4,
        duration: context.motion(SQDuration.state),
        curve: SQCurve.arrive,
        child: AnimatedOpacity(
          opacity: paid ? 1 : 0,
          duration: context.motion(SQDuration.tap),
          child: const Icon(Icons.check_rounded, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}
