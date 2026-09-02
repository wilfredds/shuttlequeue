/// Sino ang susunod na maglalaro.
///
/// Puro Dart ito — walang Firestore — kaya masusubok nang mag-isa. Dito
/// nakasalalay ang buong pakiramdam ng gabi, kaya bawat panuntunan ay may
/// test sa `test/services/matchmaking_service_test.dart`.
///
/// Ang algorithm ay **nagmumungkahi lang**. Palaging pwedeng palitan ng QM
/// ang kahit sinong napili bago simulan ang laro.
library;

import '../models/match.dart';
import '../models/session_player.dart';

/// Ang mungkahi para sa isang court.
class MatchSuggestion {
  const MatchSuggestion({
    required this.teamA,
    required this.teamB,
    required this.isMixedSkill,
    required this.forcedByLongWait,
  });

  final List<SessionPlayer> teamA;
  final List<SessionPlayer> teamB;

  /// Walang malinis na grupo ng magkakalapit na tier — ipapakita ito sa QM
  /// imbes na harangin ang laro (spec §5.4).
  final bool isMixedSkill;

  /// Mga isiningit dahil sobrang tagal nang naghihintay.
  final List<SessionPlayer> forcedByLongWait;

  List<SessionPlayer> get allPlayers => [...teamA, ...teamB];
}

class MatchmakingService {
  const MatchmakingService({
    this.maxWait = const Duration(minutes: 25),
    this.varietyWindow = 6,
  });

  /// Pagkalipas nito, isinisingit ang manlalaro kahit hindi bagay ang tier.
  ///
  /// Ito ang safety valve ng buong sistema: **tiyak** na maiiwan ng
  /// skill-grouping ang nag-iisang advanced o nag-iisang beginner. Isang
  /// taong walang laro buong gabi ang pinakamasamang posibleng resulta —
  /// mas masahol pa kaysa sa hindi pantay na laban.
  final Duration maxWait;

  /// Gaano kalayo tayo titingin sa pila para maiwasan ang paulit-ulit na
  /// magkakasama. Mas malaki = mas maraming variety pero mas maluwag ang
  /// pagkakasunod-sunod. Anim ang balanse.
  final int varietyWindow;

  /// Bumabalik ng null kapag kulang sa apat ang nasa pila.
  MatchSuggestion? suggestNext({
    required List<SessionPlayer> players,
    required DateTime now,
    List<GameMatch> history = const [],
  }) {
    final candidates = players.where((p) => p.status.isEligibleForMatch).toList();
    if (candidates.length < 4) return null;

    // Puso ng fairness: pinakakaunting laro muna; kapag patas, ang
    // pinakamatagal nang naghihintay.
    candidates.sort((a, b) {
      final byGames = a.gamesPlayed.compareTo(b.gamesPlayed);
      if (byGames != 0) return byGames;
      return a.waitingSince.compareTo(b.waitingSince);
    });

    // Nananatili ang fairness order dito: ang unang long-waiter sa pila ay
    // siya ring may pinakakaunting laro sa kanila. Kung isasaayos natin ito
    // ayon sa haba ng hintay lang, maisisingit ang may mas maraming laro at
    // masisira ang pagkakapantay-pantay sa buong gabi.
    final longWaiters = candidates
        .where((p) => now.difference(p.waitingSince) >= maxWait)
        .toList();

    // Ang anchor ang tumatakda ng tier ng laban. Kung may sobrang tagal
    // nang naghihintay, siya ang anchor — kahit ano pang tier niya.
    final anchor = longWaiters.isNotEmpty ? longWaiters.first : candidates.first;
    final pool = candidates.where((p) => p.id != anchor.id).toList();

    final pairCounts = _pairCounts(history);

    // Magkalapit na tier (0 o 1 ang layo) ang mas gusto natin.
    final compatible =
        pool.where((p) => p.skillTier.distanceTo(anchor.skillTier) <= 1).toList();

    List<SessionPlayer> companions;
    var isMixedSkill = false;

    if (compatible.length >= 3) {
      companions = _pickWithVariety(anchor, compatible, pairCounts);
    } else {
      // Walang sapat na kalapit na tier — hindi tayo humihinto, nagbabandera
      // lang tayo. Mas mabuting hindi pantay na laban kaysa walang laro.
      isMixedSkill = true;
      final rest = pool.where((p) => !compatible.contains(p)).toList();
      companions = [...compatible, ...rest].take(3).toList();
    }

    final four = [anchor, ...companions];

    // Kung may ibang matagal nang naghihintay na nakapasok, banggitin din.
    final forced = four
        .where((p) => now.difference(p.waitingSince) >= maxWait)
        .toList();

    final (teamA, teamB) = _balanceTeams(four);

    return MatchSuggestion(
      teamA: teamA,
      teamB: teamB,
      isMixedSkill: isMixedSkill || _spread(four) > 1,
      forcedByLongWait: forced,
    );
  }

  /// Pumipili ng tatlong kasama.
  ///
  /// MAHALAGANG PANUNTUNAN: **ang variety ay tie-breaker lang, hindi kailanman
  /// nakakalampas sa fairness.** Kinukuha muna ang lahat ng may pinakakaunting
  /// laro; sa loob lang ng magkakaparehong bilang tayo pumipili ng hindi pa
  /// nagkakasama. Kapag pinayagan nating manghila ang variety sa buong pila,
  /// unti-unting lumalayo ang bilang ng laro sa isa't isa — napatunayan ito
  /// ng "simulated night" na test.
  List<SessionPlayer> _pickWithVariety(
    SessionPlayer anchor,
    List<SessionPlayer> compatible,
    Map<String, int> pairCounts,
  ) {
    final chosen = <SessionPlayer>[];
    var remaining = compatible;

    while (chosen.length < 3 && remaining.isNotEmpty) {
      final games = remaining.first.gamesPlayed;
      final tied = remaining.where((p) => p.gamesPlayed == games).toList();
      final need = 3 - chosen.length;

      if (tied.length <= need) {
        chosen.addAll(tied);
      } else {
        chosen.addAll(_bestCombo(anchor, chosen, tied, need, pairCounts));
      }

      remaining =
          remaining.where((p) => p.gamesPlayed > games).toList(growable: false);
    }

    return chosen.take(3).toList();
  }

  /// Pumipili ng `need` mula sa mga magkakapantay sa bilang ng laro,
  /// iniiwasan ang mga kalalaro lang. Ang posisyon sa pila (haba ng hintay)
  /// ang tie-breaker kapag pareho ang dami ng ulit.
  List<SessionPlayer> _bestCombo(
    SessionPlayer anchor,
    List<SessionPlayer> alreadyChosen,
    List<SessionPlayer> tied,
    int need,
    Map<String, int> pairCounts,
  ) {
    final window = tied.take(varietyWindow).toList();

    List<SessionPlayer>? best;
    var bestCost = 1 << 30;

    for (final combo in _combinations(window, need)) {
      final group = [anchor, ...alreadyChosen, ...combo.values];
      final cost = _repeatCost(group, pairCounts) * 100 + combo.positionSum;
      if (cost < bestCost) {
        bestCost = cost;
        best = combo.values;
      }
    }

    return best ?? window.take(need).toList();
  }

  Iterable<({List<SessionPlayer> values, int positionSum})> _combinations(
    List<SessionPlayer> source,
    int size,
  ) sync* {
    final indices = List<int>.generate(size, (i) => i);
    if (source.length < size) {
      yield (values: source, positionSum: 0);
      return;
    }

    while (true) {
      yield (
        values: [for (final i in indices) source[i]],
        positionSum: indices.fold(0, (sum, i) => sum + i),
      );

      var pivot = size - 1;
      while (pivot >= 0 && indices[pivot] == source.length - size + pivot) {
        pivot--;
      }
      if (pivot < 0) return;

      indices[pivot]++;
      for (var i = pivot + 1; i < size; i++) {
        indices[i] = indices[i - 1] + 1;
      }
    }
  }

  int _repeatCost(List<SessionPlayer> group, Map<String, int> pairCounts) {
    var total = 0;
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        total += pairCounts[_pairKey(group[i].id, group[j].id)] ?? 0;
      }
    }
    return total;
  }

  /// Ilang beses nagkasama sa iisang court ang bawat pares ngayong gabi.
  Map<String, int> _pairCounts(List<GameMatch> history) {
    final counts = <String, int>{};
    for (final match in history) {
      final ids = match.allPlayerIds;
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final key = _pairKey(ids[i], ids[j]);
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  String _pairKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  /// Hinahati ang apat sa dalawang pantay na koponan.
  ///
  /// Pinakamalakas + pinakamahina laban sa dalawang nasa gitna — ito ang
  /// pinakamalapit sa pantay kapag tier lang ang alam natin.
  (List<SessionPlayer>, List<SessionPlayer>) _balanceTeams(
    List<SessionPlayer> four,
  ) {
    final sorted = [...four]
      ..sort((a, b) => b.skillTier.index.compareTo(a.skillTier.index));
    return (
      [sorted[0], sorted[3]],
      [sorted[1], sorted[2]],
    );
  }

  int _spread(List<SessionPlayer> group) {
    final tiers = group.map((p) => p.skillTier.index);
    return tiers.reduce((a, b) => a > b ? a : b) -
        tiers.reduce((a, b) => a < b ? a : b);
  }
}

/// Ang susunod na papasok sa pila, ayon sa parehong panuntunan ng fairness.
/// Ginagamit ng "up next" na listahan sa courts screen.
List<SessionPlayer> queueOrder(List<SessionPlayer> players) {
  final queued =
      players.where((p) => p.status.isEligibleForMatch).toList();
  queued.sort((a, b) {
    final byGames = a.gamesPlayed.compareTo(b.gamesPlayed);
    if (byGames != 0) return byGames;
    return a.waitingSince.compareTo(b.waitingSince);
  });
  return queued;
}
