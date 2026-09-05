/// Ang buod ng gabi, kada manlalaro.
///
/// Ito ang bahaging ipagmamalaki ng mga tao — ang isc-screenshot at
/// ipinapaskil sa group chat. Walang dagdag na trabaho para sa QM: bawat
/// numero dito ay naitala na ng rotation engine habang tumatakbo ang gabi.
///
/// Puro Dart, walang Firestore — kaya masusubok nang eksakto.
///
/// DALAWANG DESISYON SA DISENYO NA SINASADYA:
///
///  1. **Walang ranking ng "pinakamaraming laro".** Madaling gawing
///     leaderboard ito, pero sa isang social club, ang ibig sabihin ng
///     "siya ang pinakamaraming laro" ay "siya ang naghari sa court".
///     Hindi natin gagawing hidwaan ang isang masayang gabi. Puro
///     neutral na datos, nakaayos ayon sa pangalan.
///
///  2. **Walang skill tier kahit saan dito.** Ibinabahagi ito sa buong
///     grupo (R-16) — ang QM lang ang dapat makakita ng tier.
library;

import '../models/match.dart';
import '../models/session_player.dart';

class PlayerRecap {
  const PlayerRecap({
    required this.playerId,
    required this.name,
    required this.gamesPlayed,
    required this.shuttlesUsed,
    required this.distinctPartners,
    required this.distinctOpponents,
    required this.longestWait,
    this.mostFrequentPartner,
    this.mostFrequentPartnerCount = 0,
  });

  final String playerId;
  final String name;

  /// Mula sa player document — ito ang opisyal na bilang na ginagamit ng
  /// fairness, hindi ang bilang ng match records.
  final int gamesPlayed;

  final int shuttlesUsed;

  /// Ilang magkakaibang tao ang naging kakampi — ito ang pinaka-positibong
  /// istatistika sa lahat. Ang isang magandang gabi ay maraming kasama,
  /// hindi paulit-ulit na apat.
  final int distinctPartners;

  final int distinctOpponents;

  /// Ang pinakamahabang pagitan bago siya nakabalik sa court.
  /// Null kapag hindi pa siya nakakalaro.
  final Duration? longestWait;

  final String? mostFrequentPartner;
  final int mostFrequentPartnerCount;

  bool get didPlay => gamesPlayed > 0;
}

class NightRecap {
  const NightRecap({
    required this.players,
    required this.totalGames,
    required this.totalShuttles,
    required this.sessionLength,
  });

  /// Nakaayos ayon sa pangalan — sinasadya. Tingnan ang komento sa itaas.
  final List<PlayerRecap> players;

  final int totalGames;
  final int totalShuttles;

  /// Mula sa simula ng unang laro hanggang matapos ang huli.
  /// Null kapag walang natapos na laro.
  final Duration? sessionLength;

  int get playerCount => players.length;

  /// Kabuuang bilang ng magkakaibang pares na naganap ngayong gabi —
  /// panukat kung gaano kahalo ang gabi.
  int get playersWhoPlayed => players.where((p) => p.didPlay).length;
}

NightRecap buildNightRecap({
  required List<SessionPlayer> players,
  required List<GameMatch> matches,
}) {
  // Tapos na lang ang binibilang. Ang kasalukuyang laro ay hindi pa
  // naitatala sa gamesPlayed ng player, kaya kung isasama natin ito rito,
  // hindi magkakatugma ang dalawang bilang sa iisang screen.
  final finished = matches.where((m) => !m.isInProgress).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  final nameOf = {for (final p in players) p.id: p.name};

  // playerId -> (partnerId -> ilang beses)
  final partners = <String, Map<String, int>>{};
  final opponents = <String, Set<String>>{};
  // playerId -> mga laro niya, ayon sa oras
  final matchesOf = <String, List<GameMatch>>{};

  for (final match in finished) {
    for (final (team, rivals) in [
      (match.teamA, match.teamB),
      (match.teamB, match.teamA),
    ]) {
      for (final playerId in team) {
        matchesOf.putIfAbsent(playerId, () => []).add(match);

        for (final mate in team) {
          if (mate == playerId) continue;
          final counts = partners.putIfAbsent(playerId, () => {});
          counts[mate] = (counts[mate] ?? 0) + 1;
        }
        opponents.putIfAbsent(playerId, () => {}).addAll(rivals);
      }
    }
  }

  final recaps = <PlayerRecap>[];

  for (final player in players) {
    final partnerCounts = partners[player.id] ?? const <String, int>{};

    // Ang pinakamadalas na kakampi. Kapag tabla, ang pangalan ang
    // tiebreaker para hindi magbago ang resulta sa bawat pag-render.
    String? topPartnerId;
    var topCount = 0;
    final sortedPartnerIds = partnerCounts.keys.toList()
      ..sort((a, b) {
        final byCount = partnerCounts[b]!.compareTo(partnerCounts[a]!);
        if (byCount != 0) return byCount;
        return (nameOf[a] ?? a).compareTo(nameOf[b] ?? b);
      });
    if (sortedPartnerIds.isNotEmpty) {
      topPartnerId = sortedPartnerIds.first;
      topCount = partnerCounts[topPartnerId]!;
    }

    recaps.add(
      PlayerRecap(
        playerId: player.id,
        name: player.name,
        gamesPlayed: player.gamesPlayed,
        shuttlesUsed: player.shuttlesUsed,
        distinctPartners: partnerCounts.length,
        distinctOpponents: (opponents[player.id] ?? const <String>{}).length,
        longestWait: _longestWait(player, matchesOf[player.id] ?? const []),
        mostFrequentPartner:
            topPartnerId == null ? null : nameOf[topPartnerId] ?? topPartnerId,
        mostFrequentPartnerCount: topCount,
      ),
    );
  }

  recaps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final totalShuttles =
      players.fold(0, (sum, p) => sum + p.shuttlesUsed);

  Duration? sessionLength;
  if (finished.isNotEmpty) {
    final start = finished.first.startedAt;
    final end = finished
        .map((m) => m.endedAt!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final span = end.difference(start);
    if (!span.isNegative) sessionLength = span;
  }

  return NightRecap(
    players: recaps,
    totalGames: finished.length,
    totalShuttles: totalShuttles,
    sessionLength: sessionLength,
  );
}

/// Ang pinakamahabang paghihintay bago makabalik sa court.
///
/// Hindi natin ito kayang basahin sa `waitingSince` — isang halaga lang
/// iyon na pinapalitan tuwing babalik siya sa pila, kaya wala tayong
/// kasaysayan doon. Pero nakukuwenta natin ito mula sa mga laro mismo:
/// ang puwang sa pagitan ng pagtatapos ng isang laro at pagsisimula ng
/// susunod. Kasama ang unang paghihintay — mula nang idagdag siya sa
/// roster hanggang sa una niyang laro.
Duration? _longestWait(SessionPlayer player, List<GameMatch> theirMatches) {
  if (theirMatches.isEmpty) return null;

  final sorted = [...theirMatches]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  var longest = sorted.first.startedAt.difference(player.createdAt);
  if (longest.isNegative) longest = Duration.zero;

  for (var i = 1; i < sorted.length; i++) {
    final previousEnd = sorted[i - 1].endedAt;
    if (previousEnd == null) continue;
    final gap = sorted[i].startedAt.difference(previousEnd);
    if (!gap.isNegative && gap > longest) longest = gap;
  }

  return longest;
}
