import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../providers/session_providers.dart';
import '../repositories/player_repository.dart';
import '../services/roster_parser.dart';
import '../widgets/skill_badge.dart';

/// Ang pinakamalaking time-saver: paste ng Messenger list papuntang roster.
///
/// Dinisenyo sa paligid ng isang katotohanan — **pwedeng magkamali ang
/// parser, basta hindi tahimik.** Lahat ng hula ay nakikita at nababago
/// bago mag-save.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _controller = TextEditingController();

  ParsedRoster _parsed = const ParsedRoster(entries: [], skippedLines: []);

  /// Nabagong pangalan at tier bago i-save — hawak dito, hindi sa parser.
  final _names = <int, String>{};
  final _tiers = <int, SkillTier>{};
  final _dropped = <int>{};

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
      _rescued.clear();
    });
  }

  List<NewPlayer> _buildPlayers() {
    final players = <NewPlayer>[];
    for (var i = 0; i < _parsed.entries.length; i++) {
      if (_dropped.contains(i)) continue;
      final name = (_names[i] ?? _parsed.entries[i].name).trim();
      if (name.isEmpty) continue;
      players.add(
        NewPlayer(
          name: name,
          skillTier: _tiers[i] ?? SkillTier.intermediate,
        ),
      );
    }
    for (final name in _rescued) {
      players.add(NewPlayer(name: name));
    }
    return players;
  }

  Future<void> _save() async {
    final players = _buildPlayers();
    if (players.isEmpty) return;

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    await ref
        .read(playerRepositoryProvider)
        .addPlayers(widget.sessionId, players);

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final keptCount = _buildPlayers().length;

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

              // R-07: hindi kailanman awtomatikong pinagsasama ang magkaparehong
              // pangalan — ipinapaalam lang sa QM na siya ang magpasya.
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
                  tier: _tiers[i] ?? SkillTier.intermediate,
                  isDropped: _dropped.contains(i),
                  onNameChanged: (value) => setState(() => _names[i] = value),
                  onTierChanged: (value) => setState(() => _tiers[i] = value),
                  onToggleDropped: () => setState(() {
                    if (!_dropped.remove(i)) _dropped.add(i);
                  }),
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
          onPressed: (keptCount == 0 || _isSaving) ? null : _save,
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
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.name,
    required this.tier,
    required this.isDropped,
    required this.onNameChanged,
    required this.onTierChanged,
    required this.onToggleDropped,
  });

  final ParsedEntry entry;
  final String name;
  final SkillTier tier;
  final bool isDropped;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<SkillTier> onTierChanged;
  final VoidCallback onToggleDropped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
