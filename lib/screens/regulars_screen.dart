import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/club_member.dart';
import '../models/enums.dart';
import '../providers/session_providers.dart';
import '../services/money.dart';
import '../widgets/skill_badge.dart';

/// Ang regulars book, nakikita at naaayos.
///
/// Kailangang makita ng QM kung ano ang naaalala ng app — kung mali ang
/// tier ng isang tao, dapat matama niya ito nang hindi hinihintay ang
/// susunod na import. Dito rin makikita ang mga dalang utang.
class RegularsScreen extends ConsumerWidget {
  const RegularsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final members = ref.watch(clubMembersProvider).value ?? const <ClubMember>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.regularsTitle)),
      body: members.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 72,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.regularsEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
              itemCount: members.length,
              itemBuilder: (context, index) =>
                  _MemberTile(member: members[index]),
            ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final ClubMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final subtitle = <String>[
      l10n.importSessionsAttended(member.sessionsAttended),
      if (member.aliases.isNotEmpty) member.aliases.join(', '),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          children: [
            SkillTierSelector(
              value: member.skillTier,
              onChanged: (tier) => _changeTier(ref, tier),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: theme.textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Dalang utang o sobrang bayad mula sa nakaraang gabi.
                  if (member.hasOutstandingBalance)
                    Text(
                      member.balanceCentavos > 0
                          ? l10n.balanceOwed(
                              formatCentavos(member.balanceCentavos))
                          : l10n.balanceCredit(
                              formatCentavos(-member.balanceCentavos)),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: member.balanceCentavos > 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.deleteMember,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remove(context, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeTier(WidgetRef ref, SkillTier tier) async {
    final clubId = ref.read(defaultClubIdProvider).value;
    if (clubId == null) return;
    await ref
        .read(clubRepositoryProvider)
        .updateMember(clubId, member.id, skillTier: tier);
  }

  /// Tunay na pagbura — kailangan ito ng RA 10173 kapag humiling ang isang
  /// manlalaro na alisin ang datos niya. Hindi nito ginagalaw ang mga
  /// nakaraang session; ang pag-alala lang ang tinatanggal.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final clubId = ref.read(defaultClubIdProvider).value;
    if (clubId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(clubRepositoryProvider).deleteMember(clubId, member.id);

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.memberDeleted(member.name))),
    );
  }
}
