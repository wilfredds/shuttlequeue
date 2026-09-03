/// Itinutugma ang pinaste na pangalan sa mga regular ng club.
///
/// Ito ang dahilan kung bakit mas mabilis ang pangalawang linggo kaysa sa
/// una: kapag natukoy si "Kuya Jun" bilang si Jun na advanced, hindi na
/// kailangang i-tag ulit ng QM ang skill niya.
///
/// PANUNTUNAN NA HINDI NAGBABAGO (R-07): kapag **hindi tiyak**, huwag
/// magpasya. Mas mabuting hindi matukoy si Jun kaysa isipin nating siya
/// ang ibang Jun — ang maling pagsasama ay gumagawa ng multong manlalaro
/// na may dobleng laro at maling bayarin.
library;

import '../models/club_member.dart';

enum MatchConfidence {
  /// Pareho ang pangalan, o kilalang palayaw ito.
  exact,

  /// Halos tiyak: isang typo lang, o unang pangalan lang ang binanggit.
  likely,

  /// Maraming pwedeng tugma — hindi tayo pipili para sa QM.
  ambiguous,

  /// Bago sa club.
  none,
}

class NameMatch {
  const NameMatch({
    required this.confidence,
    this.member,
    this.alternatives = const [],
  });

  final MatchConfidence confidence;
  final ClubMember? member;

  /// Kapag ambiguous: lahat ng posibleng tao, para makapili ang QM.
  final List<ClubMember> alternatives;

  /// Ligtas bang gamitin agad ang naaalalang skill tier?
  bool get isConfident =>
      member != null &&
      (confidence == MatchConfidence.exact ||
          confidence == MatchConfidence.likely);
}

/// Mga panlaping panggalang na hindi bahagi ng pangalan.
const _honorifics = {
  'kuya', 'ate', 'tito', 'tita', 'sir', 'maam', 'ma', 'mam',
  'coach', 'doc', 'engr', 'atty', 'mr', 'mrs', 'ms',
};

/// Nililinis ang pangalan para sa paghahambing lang — hindi ito ang
/// ipinapakita sa screen. Ang orihinal na baybay ang pinapanatili natin.
String normalizeName(String raw) {
  var text = raw.toLowerCase().trim();

  // Tanggalin ang bantas maliban sa espasyo; panatilihin ang mga letrang
  // may tuldik (ñ, é) dahil bahagi sila ng totoong pangalan.
  text = text.replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  final words = text.split(' ').where((w) => w.isNotEmpty).toList();

  // Alisin ang panggalang sa unahan — pero hindi kung iyon lang ang meron
  // (baka "Ate" talaga ang tawag sa kanya).
  while (words.length > 1 && _honorifics.contains(words.first)) {
    words.removeAt(0);
  }

  return words.join(' ');
}

/// Ilang pagbabago bago maging pareho ang dalawang salita: palit, dagdag,
/// bawas, at **paglipat ng dalawang magkatabing letra**.
///
/// Kasama ang huli (Damerau–Levenshtein) dahil iyon ang pinakakaraniwang
/// typo kapag mabilis nagta-type sa group chat: "Poalo" imbes na "Paolo".
/// Sa payak na Levenshtein, dalawang pagbabago iyon at hindi matutukoy —
/// kahit isang pagkakamali lang naman talaga ng daliri.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Tatlong hilera: kailangan ng transposition ang hilerang dalawang
  // hakbang pabalik.
  var beforePrevious = List<int>.filled(b.length + 1, 0);
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      var best = previous[j + 1] + 1; // bawas
      final insertion = current[j] + 1;
      if (insertion < best) best = insertion;
      final substitution = previous[j] + cost;
      if (substitution < best) best = substitution;

      // Nagpalitan ba ng puwesto ang dalawang magkatabing letra?
      if (i > 0 &&
          j > 0 &&
          a.codeUnitAt(i) == b.codeUnitAt(j - 1) &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j)) {
        final transposition = beforePrevious[j - 1] + 1;
        if (transposition < best) best = transposition;
      }

      current[j + 1] = best;
    }

    beforePrevious = previous;
    previous = current;
    current = List<int>.filled(b.length + 1, 0);
  }

  return previous[b.length];
}

/// Hinahanap ang regular na tumutugma sa isang pinaste na pangalan.
NameMatch matchMember(String pastedName, List<ClubMember> members) {
  final needle = normalizeName(pastedName);
  if (needle.isEmpty || members.isEmpty) {
    return const NameMatch(confidence: MatchConfidence.none);
  }

  // 1. Tamang-tama ang pangalan o isa sa mga palayaw.
  final exact = members
      .where((m) => m.allNames.any((n) => normalizeName(n) == needle))
      .toList();
  if (exact.length == 1) {
    return NameMatch(confidence: MatchConfidence.exact, member: exact.first);
  }
  if (exact.length > 1) {
    // Dalawang regular na pareho ang pangalan — dito eksaktong nabubuhay
    // ang problemang "dalawang Jun". Ang QM ang magpapasya.
    return NameMatch(
      confidence: MatchConfidence.ambiguous,
      alternatives: exact,
    );
  }

  // 2. Unang pangalan lang ang binanggit: "Jun" para kay "Jun Padilla",
  //    o "Jun P." para kay "Jun".
  final needleFirst = needle.split(' ').first;
  final prefixMatches = members.where((m) {
    return m.allNames.any((n) {
      final candidate = normalizeName(n);
      if (candidate.isEmpty) return false;
      final candidateFirst = candidate.split(' ').first;
      return candidateFirst == needleFirst;
    });
  }).toList();

  if (prefixMatches.length == 1) {
    return NameMatch(
      confidence: MatchConfidence.likely,
      member: prefixMatches.first,
    );
  }
  if (prefixMatches.length > 1) {
    return NameMatch(
      confidence: MatchConfidence.ambiguous,
      alternatives: prefixMatches,
    );
  }

  // 3. Typo: isang letra lang ang pagkakaiba. Sa maiikling pangalan,
  //    masyadong mapanganib ito ("Ana" vs "Ann"), kaya 5 letra pataas lang.
  if (needle.length >= 5) {
    final typoMatches = members
        .where((m) => m.allNames
            .any((n) => editDistance(normalizeName(n), needle) == 1))
        .toList();
    if (typoMatches.length == 1) {
      return NameMatch(
        confidence: MatchConfidence.likely,
        member: typoMatches.first,
      );
    }
    if (typoMatches.length > 1) {
      return NameMatch(
        confidence: MatchConfidence.ambiguous,
        alternatives: typoMatches,
      );
    }
  }

  return const NameMatch(confidence: MatchConfidence.none);
}
