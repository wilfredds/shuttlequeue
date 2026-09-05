import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../providers/session_providers.dart';
import '../services/money.dart';
import '../services/session_schedule.dart';

/// Gumawa o mag-edit ng session. Piso ang ipinapakita; centavos ang
/// iniimbak — sa boundary na ito nangyayari ang conversion, isang beses lang.
///
/// Tatlong gamit ng screen na ito:
///  - bagong session (parehong null)
///  - pag-edit ng meron na (`existing`)
///  - pag-uulit ng nakaraang gabi (`template`) — bagong session pa rin,
///    pero puno na ang lahat ng detalye maliban sa petsa
class SessionFormScreen extends ConsumerStatefulWidget {
  const SessionFormScreen({super.key, this.existing, this.template})
      : assert(
          existing == null || template == null,
          'edit a session or repeat one, never both',
        );

  final Session? existing;

  /// Kinokopya ang mga detalye pero **bagong session pa rin** ang ginagawa.
  /// Lingguhan ang club, kaya halos lahat ng field ay pareho na sa
  /// nakaraang linggo — ang petsa lang ang talagang nagbabago.
  final Session? template;

  @override
  ConsumerState<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends ConsumerState<SessionFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _venueController;
  late final TextEditingController _courtFeeController;
  late final TextEditingController _shuttlePriceController;

  late DateTime _sessionDate;
  late int _courtCount;
  late FeeMode _feeMode;

  var _isSaving = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    // Pareho ang pinagkukunan ng laman ng form kung ini-edit o inuulit;
    // ang pinagkaiba ay kung ano ang mangyayari sa Save at kung anong
    // petsa ang mungkahi.
    final source = widget.existing ?? widget.template;

    _titleController = TextEditingController(text: source?.title ?? '');
    _venueController = TextEditingController(text: source?.venue ?? '');
    _courtFeeController = TextEditingController(
      text: source == null ? '' : _pesoText(source.courtFeeCentavos),
    );
    _shuttlePriceController = TextEditingController(
      text: source == null ? '' : _pesoText(source.shuttlePriceCentavos),
    );

    final now = DateTime.now();
    _sessionDate = switch ((widget.existing, widget.template)) {
      // Pag-edit: huwag galawin ang petsa.
      (final Session existing, _) => existing.sessionDate,
      // Pag-uulit: ang susunod na katulad na araw ng linggo.
      (_, final Session template) =>
        nextOccurrence(template.sessionDate, now),
      // Bago: ngayong gabi, alas-8 — ang pinakakaraniwang oras ng palo.
      _ => DateTime(now.year, now.month, now.day, 20),
    };

    _courtCount = source?.courtCount ?? 2;
    _feeMode = source?.feeMode ?? FeeMode.perHead;
  }

  /// Walang trailing ".00" kung buong piso — mas madaling i-edit.
  String _pesoText(int centavos) {
    if (centavos % 100 == 0) return (centavos ~/ 100).toString();
    return (centavos / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _courtFeeController.dispose();
    _shuttlePriceController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sessionDate),
    );
    if (!mounted) return;

    setState(() {
      _sessionDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _sessionDate.hour,
        time?.minute ?? _sessionDate.minute,
      );
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    final title = _titleController.text.trim();
    final venue = _venueController.text.trim();

    if (title.isEmpty) {
      setState(() => _errorText = l10n.errSessionNameRequired);
      return;
    }
    if (venue.isEmpty) {
      setState(() => _errorText = l10n.errVenueRequired);
      return;
    }
    if (_courtCount < 1 || _courtCount > 12) {
      setState(() => _errorText = l10n.errCourtsRange);
      return;
    }

    // Blangko = libre. Mas mabait ito kaysa pilitin ang QM na mag-type ng 0.
    final courtFee = _courtFeeController.text.trim().isEmpty
        ? 0
        : parsePesosToCentavos(_courtFeeController.text);
    final shuttlePrice = _shuttlePriceController.text.trim().isEmpty
        ? 0
        : parsePesosToCentavos(_shuttlePriceController.text);

    if (courtFee == null || shuttlePrice == null) {
      setState(() => _errorText = l10n.errFeeInvalid);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final navigator = Navigator.of(context);
    final repo = ref.read(sessionRepositoryProvider);

    try {
      if (_isEditing) {
        final existing = widget.existing!;
        await repo.updateSession(
          existing.id,
          title: title,
          venue: venue,
          sessionDate: _sessionDate,
          courtFeeCentavos: courtFee,
          shuttlePriceCentavos: shuttlePrice,
          feeMode: _feeMode,
        );
        if (_courtCount != existing.courtCount) {
          await repo.setCourtCount(existing.id, _courtCount);
        }
      } else {
        // Hinihintay ang club ID: ito ang nag-uugnay ng gabi sa regulars book.
        final clubId = await ref.read(defaultClubIdProvider.future);
        final uid = ref.read(currentUidProvider);
        if (clubId == null || uid == null) {
          throw StateError('Not signed in');
        }

        await repo.createSession(
          ownerUid: uid,
          clubId: clubId,
          title: title,
          venue: venue,
          sessionDate: _sessionDate,
          courtCount: _courtCount,
          courtFeeCentavos: courtFee,
          shuttlePriceCentavos: shuttlePrice,
          feeMode: _feeMode,
        );
      }

      navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = l10n.errUnknown;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch ((widget.existing, widget.template)) {
            (final Session _, _) => l10n.editSessionTitle,
            (_, final Session _) => l10n.repeatSessionTitle,
            _ => l10n.newSessionTitle,
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Ang petsa ang tanging hulang ginagawa natin dito, kaya
            // sinasabi natin nang tahasan na tingnan iyon.
            if (widget.template != null) ...[
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_repeat_outlined,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.repeatSessionHint,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.sessionNameLabel,
                hintText: l10n.sessionNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.event_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _venueController,
              decoration: InputDecoration(
                labelText: l10n.venueLabel,
                hintText: l10n.venueHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Petsa at oras — tap lang, walang typing.
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.dateLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  DateFormat('EEE, MMM d, y · h:mm a').format(_sessionDate),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),

            _CourtStepper(
              value: _courtCount,
              onChanged: (value) => setState(() => _courtCount = value),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _courtFeeController,
              decoration: InputDecoration(
                labelText: l10n.courtFeeLabel,
                border: const OutlineInputBorder(),
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shuttlePriceController,
              decoration: InputDecoration(
                labelText: l10n.shuttlePriceLabel,
                border: const OutlineInputBorder(),
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            Text(l10n.feeModeLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<FeeMode>(
              segments: [
                ButtonSegment(
                  value: FeeMode.perHead,
                  label: Text(l10n.feeModePerHead),
                ),
                ButtonSegment(
                  value: FeeMode.american,
                  label: Text(l10n.feeModeAmerican),
                ),
              ],
              selected: {_feeMode},
              onSelectionChanged: (selection) =>
                  setState(() => _feeMode = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              _feeMode == FeeMode.perHead
                  ? l10n.feeModePerHeadHelp
                  : l10n.feeModeAmericanHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),

            if (_errorText != null) ...[
              const SizedBox(height: 20),
              Text(
                _errorText!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 28),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      _isEditing
                          ? l10n.saveChangesButton
                          : l10n.createSessionButton,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bilang ng court: malalaking +/- na button imbes na keyboard.
class _CourtStepper extends StatelessWidget {
  const _CourtStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.courtsLabel,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.grid_view_outlined),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.courtCountLabel(value),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          IconButton.filledTonal(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
            tooltip: '−',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: value < 12 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
            tooltip: '+',
          ),
        ],
      ),
    );
  }
}
