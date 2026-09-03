/// Buong larawan ng gabi bilang plain text, kahit walang signal.
///
/// **Ito ang insurance policy ng QM (R-01, R-06).** Ang telepono niya ang
/// buong sistema: kapag naubos ang baterya nang alas-diyes, o na-clear ang
/// storage bago mag-sync, wala nang mababalikan. Isang tap dito at may
/// kopya na siyang maipapaste sa Messenger o sa Notes — gumagana offline
/// dahil puro string lang ito, walang network.
///
/// Puro Dart, walang Firestore — kaya natetest nang eksakto.
library;

import '../models/court.dart';
import '../models/enums.dart';
import '../models/match.dart';
import '../models/session.dart';
import '../models/session_player.dart';
import 'fee_calculator.dart';
import 'money.dart';

String buildSessionSnapshot({
  required Session session,
  required List<SessionPlayer> players,
  required List<Court> courts,
  required List<GameMatch> matches,
  required DateTime now,
}) {
  final buffer = StringBuffer();

  buffer.writeln(session.title);
  buffer.writeln(_formatDateTime(session.sessionDate));
  if (session.venue.isNotEmpty) buffer.writeln(session.venue);
  buffer.writeln('Snapshot: ${_formatDateTime(now)}');
  buffer.writeln();

  // --- Sino ang nandito -----------------------------------------------------
  final active = players.where((p) => p.status != PlayerStatus.left).toList();
  final left = players.where((p) => p.status == PlayerStatus.left).toList();

  buffer.writeln('PLAYERS (${players.length})');
  if (players.isEmpty) {
    buffer.writeln('  none yet');
  } else {
    // Pinakamaraming laro muna — ito ang unang tinitingnan kapag may
    // nagtatanong kung patas ba ang gabi.
    final ordered = [...players]..sort((a, b) {
        final byGames = b.gamesPlayed.compareTo(a.gamesPlayed);
        if (byGames != 0) return byGames;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    for (final player in ordered) {
      final tier = player.skillTier.value[0].toUpperCase();
      final games = '${player.gamesPlayed} game'
          '${player.gamesPlayed == 1 ? '' : 's'}';
      final status = player.status == PlayerStatus.queued
          ? ''
          : ' (${player.status.value})';
      final shuttles =
          player.shuttlesUsed > 0 ? ' · ${player.shuttlesUsed} shuttle'
              '${player.shuttlesUsed == 1 ? '' : 's'}' : '';
      buffer.writeln('  [$tier] ${player.name} — $games$status$shuttles');
    }
  }
  buffer.writeln();

  // --- Ano ang nangyayari ngayon -------------------------------------------
  final playersById = {for (final p in players) p.id: p};
  final liveMatches = {
    for (final m in matches.where((m) => m.isInProgress)) m.courtId: m,
  };

  if (courts.isNotEmpty) {
    buffer.writeln('COURTS');
    for (final court in courts) {
      final match = liveMatches[court.id];
      if (match == null) {
        buffer.writeln('  ${court.label}: free');
      } else {
        final teamA = _names(match.teamA, playersById);
        final teamB = _names(match.teamB, playersById);
        buffer.writeln('  ${court.label}: $teamA vs $teamB');
      }
    }
    buffer.writeln();
  }

  final finished = matches.where((m) => !m.isInProgress).length;
  buffer.writeln('Games finished: $finished');
  if (left.isNotEmpty) {
    buffer.writeln('Left early: ${left.map((p) => p.name).join(', ')}');
  }
  buffer.writeln();

  // --- Magkano ang bayad ----------------------------------------------------
  if (active.isNotEmpty || players.isNotEmpty) {
    final breakdown = const FeeCalculator().calculate(
      players: players,
      courtFeeCentavos: session.courtFeeCentavos,
      shuttlePriceCentavos: session.shuttlePriceCentavos,
      feeMode: session.feeMode,
    );

    if (breakdown.lines.isNotEmpty) {
      final mode =
          session.feeMode == FeeMode.perHead ? 'per head' : 'american';
      buffer.writeln('COST SPLIT ($mode)');
      for (final line in breakdown.lines) {
        final mark = line.hasPaid ? 'PAID' : '    ';
        buffer.writeln(
          '  $mark ${line.name}: ${formatCentavos(line.totalCentavos)}',
        );
      }
      buffer.writeln();
      buffer.writeln(
        'Total ${formatCentavos(breakdown.chargedTotalCentavos)} · '
        'collected ${formatCentavos(breakdown.collectedCentavos)} · '
        'owed ${formatCentavos(breakdown.outstandingCentavos)}',
      );
    }
  }

  return buffer.toString();
}

String _names(List<String> ids, Map<String, SessionPlayer> playersById) {
  final names = ids
      .map((id) => playersById[id]?.name)
      .whereType<String>()
      .toList();
  return names.isEmpty ? '?' : names.join(' & ');
}

/// Sariling formatter para manatiling pure ang service — walang intl,
/// walang locale lookup, walang dependency sa Flutter.
String _formatDateTime(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final meridiem = value.hour < 12 ? 'AM' : 'PM';
  final minute = value.minute.toString().padLeft(2, '0');
  return '${months[value.month - 1]} ${value.day}, ${value.year} · '
      '$hour12:$minute $meridiem';
}
