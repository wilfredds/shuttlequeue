import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/club_member.dart';
import '../models/enums.dart';
import '../providers/session_providers.dart';
import '../repositories/player_repository.dart';
import '../services/name_matcher.dart';
import '../services/roster_parser.dart';
import '../widgets/skill_badge.dart';

/// Ang pinakamalaking time-saver: paste ng Messenger list papuntang roster.
///
/// Dinisenyo sa paligid ng dalawang katotohanan:
///  1. **Pwedeng magkamali ang parser, basta hindi tahimik** — lahat ng hula
///     ay nakikita at nababago bago mag-save.
///  2. **Naaalala ang mga regular** — kapag nakilala si "Kuya Jun", kasama
///     na ang skill tier niya mula noong nakaraang gabi.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _controller = TextEditingController();

  ParsedRoster _parsed = const ParsedRoster(entries: [], skippedLines: []);

  /// Mga binago ng QM bago mag-save.
  final _names = <int, String>{};
  final _tiers = <int, SkillTier>{};
  final _dropped = <int>{};

  /// Manu-manong pinili ng QM nang ambiguous ang tugma.
  final _resolved = <int, ClubMember?>{};

  /// Mga linyang nilaktawan pero ibinalik ng QM bilang manlalaro.
  final _rescued = <String>[];

  var _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reparse(String raw) {
    setState(() {
      _parsed = parseRoster(raw);
      _names.clear();
      _tiers.clear();
      _dropped.clear();
      _resolved.clear();
      _rescued.clear();
    });
  }

  /// Itinutugma ang bawat linya sa regulars book. Ang manu-manong pinili ng
  /// QM ang laging nananaig sa hula ng matcher.
  NameMatch _matchFor(int index, List<ClubMember> members) {
    if (_resolved.containsKey(index)) {
      final chosen = _resolved[index];
      return chosen == null
          ? const NameMatch(confidence: MatchConfidence.none)
          : NameMatch(confidence: MatchConfidence.exact, member: chosen);
    }
    final entry = _parsed.entries[index];
    if (entry.isGuest) {
      // Ang bisita ay hindi regular — huwag idagdag sa club book.
      return const NameMatch(confidence: MatchConfidence.none);
    }
    return matchMember(_names[index] ?? entry.name, members);
  }

  SkillTier _tierFor(int index, NameMatch match) {
    final override = _tiers[index];
    if (override != null) return override;
    // Ito ang buong punto ng regulars book: naaalalang tier.
    if (match.isConfident) return match.member!.skillTier;
    return SkillTier.intermediate;
  }

  Future<void> _save(List<ClubMember> members) async {
    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final clubId = ref.read(defaultClubIdProvider).value;
    final clubRepo = ref.read(clubRepositoryProvider);
    final playerRepo = ref.read(playerRepositoryProvider);

    final toAdd = <NewPlayer>[];

    for (var i = 0; i < _parsed.entries.length; i++) {
      if (_dropped.contains(i)) continue;

      final entry = _parsed.entries[i];
      final name = (_names[i] ?? entry.name).trim();
      if (name.isEmpty) continue;

      final match = _matchFor(i, members);
      final tier = _tierFor(i, match);

      String? memberId;

      if (match.isConfident) {
        memberId = match.member!.id;

        // Binago ng QM ang tier ng isang kilalang regular — tandaan ito,
        // para sa susunod na gabi tama na agad.
        if (match.member!.skillTier != tier && clubId != null) {
          await clubRepo.updateMember(clubId, memberId, skillTier: tier);
        }
        // Bagong baybay ng pangalan (hal. "Kuya Jun") — tandaan bilang alias.
        if (clubId != null &&
            !match.member!.allNames
                .any((n) => normalizeName(n) == normalizeName(name))) {
          await clubRepo.rememberAlias(clubId, memberId, name);
        }
        if (clubId != null) {
          await clubRepo.recordAttendance(clubId, memberId);
        }
      } else if (!entry.isGuest && clubId != null) {
        // Bagong mukha: isulat sa regulars book para kilala na sa susunod.
        memberId = await clubRepo.addMember(
          clubId: clubId,
          name: name,
          skillTier: tier,
        );
        await clubRepo.recordAttendance(clubId, memberId);
      }

      toAdd.add(NewPlayer(name: name, skillTier: tier, memberId: memberId));
    }

    for (final name in _rescued) {
      toAdd.add(NewPlayer(name: name));
    }

    if (toAdd.isNotEmpty) {
      await playerRepo.addPlayers(widget.sessionId, toAdd);
    }

    navigator.pop();
  }

  int _keptCount() {
    var count = _rescued.length;
    for (var i = 0; i < _parsed.entries.length; i++) {
      if (_dropped.contains(i)) continue;
      if ((_names[i] ?? _parsed.entries[i].name).trim().isEmpty) continue;
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final members = ref.watch(clubMembersProvider).value ?? const <ClubMember>[];

    final keptCount = _keptCount();
    var recognised = 0;
    for (var i = 0; i < _parsed.entries.length; i++) {
      if (_dropped.contains(i)) continue;
      if (_matchFor(i, members).isConfident) recognised++;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              l10n.importInstructions,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 12,
              onChanged: _reparse,
              decoration: InputDecoration(
                hintText: l10n.importHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', height: 1.4),
            ),
            const SizedBox(height: 20),

            if (_parsed.isEmpty && _rescued.isEmpty)
              Text(
                l10n.importEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else ...[
              Row(
                children: [
                  Text(l10n.importPreview, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    l10n.importFoundPlayers(keptCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (recognised > 0)
                _Banner(
                  icon: Icons.badge_outlined,
                  text: l10n.importMatchedCount(recognised),
                  color: theme.colorScheme.primaryContainer,
                  onColor: theme.colorScheme.onPrimaryContainer,
                ),

              // R-07: hindi kailanman awtomatikong pinagsasama ang
              // magkaparehong pangalan — ipinapaalam lang sa QM.
              if (_parsed.duplicateCount > 0)
                _Banner(
                  icon: Icons.people_outline,
                  text: l10n.importDuplicateWarning(_parsed.duplicateCount),
                  color: theme.colorScheme.tertiaryContainer,
                  onColor: theme.colorScheme.onTertiaryContainer,
                ),

              for (var i = 0; i < _parsed.entries.length; i++)
                _EntryTile(
                  entry: _parsed.entries[i],
                  name: _names[i] ?? _parsed.entries[i].name,
                  match: _matchFor(i, members),
                  tier: _tierFor(i, _matchFor(i, members)),
                  isDropped: _dropped.contains(i),
                  onNameChanged: (value) => setState(() => _names[i] = value),
                  onTierChanged: (value) => setState(() => _tiers[i] = value),
                  onToggleDropped: () => setState(() {
                    if (!_dropped.remove(i)) _dropped.add(i);
                  }),
                  onResolve: () => _resolveAmbiguity(i, members),
                ),

              for (final name in _rescued)
                ListTile(
                  leading: const Icon(Icons.person_add_alt),
                  title: Text(name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _rescued.remove(name)),
                  ),
                ),

              if (_parsed.skippedLines.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.importSkippedLines(_parsed.skippedLines.length),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.importSkippedExplain,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final line in _parsed.skippedLines)
                      ActionChip(
                        label: Text(
                          line.length > 28 ? '${line.substring(0, 28)}…' : line,
                        ),
                        avatar: const Icon(Icons.add, size: 18),
                        onPressed: _rescued.contains(line)
                            ? null
                            : () => setState(() => _rescued.add(line)),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              // RA 10173: sinasabi sa simpleng salita kung ano ang iniimbak.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.importConsent,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FilledButton(
          onPressed: (keptCount == 0 || _isSaving) ? null : () => _save(members),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text('${l10n.importAddAll} ($keptCount)'),
        ),
      ),
    );
  }

  /// Dalawang regular na pareho ang pangalan — ang QM ang pipili.
  Future<void> _resolveAmbiguity(int index, List<ClubMember> members) async {
    final match = _matchFor(index, members);
    final options = match.alternatives.isNotEmpty ? match.alternatives : members;
    if (options.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.importPickMember,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final option in options)
              ListTile(
                leading: SkillBadge(tier: option.skillTier),
                title: Text(option.name),
                subtitle:
                    Text(l10n.importSessionsAttended(option.sessionsAttended)),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: Text(l10n.importNotThisPerson),
              onTap: () => Navigator.of(sheetContext).pop('new'),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    setState(() {
      _resolved[index] = chosen is ClubMember ? chosen : null;
    });
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.name,
    required this.match,
    required this.tier,
    required this.isDropped,
    required this.onNameChanged,
    required this.onTierChanged,
    required this.onToggleDropped,
    required this.onResolve,
  });

  final ParsedEntry entry;
  final String name;
  final NameMatch match;
  final SkillTier tier;
  final bool isDropped;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<SkillTier> onTierChanged;
  final VoidCallback onToggleDropped;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isAmbiguous = match.confidence == MatchConfidence.ambiguous;

    return Opacity(
      opacity: isDropped ? 0.4 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: name,
                      onChanged: onNameChanged,
                      enabled: !isDropped,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (entry.isGuest)
                          _MiniTag(
                            label: l10n.importGuestBadge,
                            color: theme.colorScheme.secondary,
                          )
                        else if (match.isConfident)
                          _MiniTag(
                            label: l10n.importKnownPlayer,
                            color: theme.colorScheme.primary,
                          )
                        else if (isAmbiguous)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            labelPadding: EdgeInsets.zero,
                            label: Text(l10n.importAmbiguous),
                            onPressed: onResolve,
                          ),
                        if (entry.isDuplicate)
                          _MiniTag(
                            label: '⚠',
                            color: theme.colorScheme.tertiary,
                          ),
                        if (entry.note != null)
                          Text(
                            entry.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SkillTierSelector(
                value: tier,
                onChanged: isDropped ? null : onTierChanged,
              ),
              IconButton(
                tooltip: l10n.removePlayer,
                icon: Icon(isDropped ? Icons.undo : Icons.close),
                onPressed: onToggleDropped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: onColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}
