/// Ginagawang malinis na roster ang basang-basang Messenger list.
///
/// Ito ang pinakamalaking time-saver ng buong app — dati, tina-type ng QM
/// ang bawat pangalan sa Excel. Pure Dart ito (walang Firestore) kaya
/// natetest nang mag-isa laban sa totoong pinaste ng grupo.
///
/// DALAWANG PANUNTUNAN NA HINDI PWEDENG BALIWALAIN:
/// 1. **Huwag mag-merge ng magkaparehong pangalan.** Sa 127-member club,
///    may dalawang "Jun" talaga. Ang pag-iisa sa kanila ay gumagawa ng
///    multong manlalaro na may dobleng laro at maling bayarin (R-07).
/// 2. **Huwag tahimik na magtapon ng linya.** Ipinapakita natin kung ano
///    ang nilaktawan para makita at maibalik ng QM (R-08).
library;

/// Isang linyang naging kandidatong manlalaro.
class ParsedEntry {
  const ParsedEntry({
    required this.name,
    required this.rawLine,
    this.note,
    this.isGuest = false,
    this.isDuplicate = false,
  });

  final String name;

  /// Ang orihinal na linya — para maipakita kung saan galing ang pangalan.
  final String rawLine;

  /// Anumang nasa panaklong: "(late 9pm)", "(maybe)".
  final String? note;

  /// Galing sa "+1" — may kasamang bisita ang isang tao.
  final bool isGuest;

  /// May kaparehong pangalan nang naunang linya. **Flag lang, hindi merge.**
  final bool isDuplicate;

  ParsedEntry copyWith({String? name, bool? isDuplicate}) => ParsedEntry(
        name: name ?? this.name,
        rawLine: rawLine,
        note: note,
        isGuest: isGuest,
        isDuplicate: isDuplicate ?? this.isDuplicate,
      );
}

class ParsedRoster {
  const ParsedRoster({required this.entries, required this.skippedLines});

  final List<ParsedEntry> entries;

  /// Mga linyang hinusgahan nating header o ingay. Ipinapakita sa preview
  /// para may pagkakataong itama ng QM ang hula natin.
  final List<String> skippedLines;

  bool get isEmpty => entries.isEmpty;
  int get duplicateCount => entries.where((e) => e.isDuplicate).length;
}

// ---------------------------------------------------------------------------

/// Numbering na nakikita sa totoong listahan: "1." "2)" "3 -" "#4" "05."
final _numbering = RegExp(r'^\s*[#(]?\s*(\d{1,3})\s*[)\].\-–—:]+\s*');

/// Numbering na space lang ang hiwalay: "1 Jun", "#4 Paolo".
final _numberingLoose = RegExp(r'^\s*[#(]?\s*(\d{1,3})\s+(?=\S)');

/// "+1", "+ 2", "plus 1" — nagdadala ng bisita.
final _guestSuffix = RegExp(r'[+]\s*(\d{1,2})\s*$|\bplus\s*(\d{1,2})\s*$',
    caseSensitive: false);

/// Anumang nasa panaklong: "(late 9pm)".
final _parenthetical = RegExp(r'[（(]([^)）]*)[)）]');

/// Emoji at mga simbolong pang-dekorasyon. Sinasadyang hindi kasama ang
/// mga letrang may accent (ñ, é) — pangalan ang mga iyon, hindi ingay.
final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2460}-\u{24FF}'
  r'\u{25A0}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]',
  unicode: true,
);

/// Petsa: buwan na KATABI ng araw ("July 06", "6 Jul").
///
/// MAHALAGA: hindi sapat ang buwan lang. Sa Pilipinas, "Jun" ay palayaw —
/// at "May" din. Kung "may buwan + may numero kahit saan" ang panuntunan,
/// mabubura natin si Jun sa roster. Kailangang magkatabi talaga sila.
final _dateish = RegExp(
  r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}\b'
  r'|\b\d{1,2}\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b',
  caseSensitive: false,
);

/// Oras: "8pm", "8:00 PM", "12mn", "9nn".
final _timeish = RegExp(
  r'\b\d{1,2}\s*(:\s*\d{2})?\s*(am|pm|mn|nn|a\.m\.|p\.m\.)\b',
  caseSensitive: false,
);

/// Mga salitang lumalabas sa header, hindi sa pangalan.
final _headerWords = RegExp(
  r'\b(court|courts|venue|fee|shuttle|game|games|night|sched|schedule|'
  r'players?|list|attendance|confirm(ed)?|paid|reserved?|slots?|open|'
  r'whos?\s+in|sino|kanino|bayad)\b',
  caseSensitive: false,
);

/// Puro simbolo o guhit: "---", "===", "•••".
final _separatorOnly = RegExp(r'^[\s\-–—=_*~•·.]+$');

/// Trailing na marka pagkatapos ng pangalan: "Jun - paid", "Ana ✓".
final _trailingMarks = RegExp(r'[\s\-–—:,;/|]+$');

// ---------------------------------------------------------------------------

/// Ang pangunahing entry point.
ParsedRoster parseRoster(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));

  // Ilang linya ang may numero sa unahan? Kung marami, "numbered list" ito
  // at ang mga walang numero ay halos tiyak na header o usapan.
  var numberedCount = 0;
  for (final line in lines) {
    if (_numbering.hasMatch(line) || _numberingLoose.hasMatch(line)) {
      numberedCount++;
    }
  }
  final numberedMode = numberedCount >= 2;

  final entries = <ParsedEntry>[];
  final skipped = <String>[];
  final seenNames = <String>{};

  for (final rawLine in lines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) continue;

    final hadNumber =
        _numbering.hasMatch(rawLine) || _numberingLoose.hasMatch(rawLine);

    // Sa numbered mode, ang walang numero ay ingay — pero ipinapakita pa rin.
    if (numberedMode && !hadNumber) {
      skipped.add(trimmed);
      continue;
    }

    if (!numberedMode && _looksLikeHeader(trimmed)) {
      skipped.add(trimmed);
      continue;
    }

    final parsed = _parseLine(rawLine);
    if (parsed == null) {
      skipped.add(trimmed);
      continue;
    }

    // Case-insensitive na paghahambing — pero FLAG lang, hindi tinatanggal.
    final key = parsed.name.toLowerCase();
    final isDuplicate = seenNames.contains(key);
    seenNames.add(key);

    entries.add(parsed.copyWith(isDuplicate: isDuplicate));

    // "+1" = may kasamang bisita. Isang hiwalay na row ito para may
    // sariling bilang ng laro at sariling hati sa bayad.
    final guestCount = _guestCount(rawLine);
    for (var i = 0; i < guestCount; i++) {
      entries.add(
        ParsedEntry(
          name: guestCount == 1
              ? '${parsed.name} +1'
              : '${parsed.name} +${i + 1}',
          rawLine: rawLine.trim(),
          isGuest: true,
        ),
      );
    }
  }

  return ParsedRoster(entries: entries, skippedLines: skipped);
}

bool _looksLikeHeader(String line) {
  if (_separatorOnly.hasMatch(line)) return true;

  // Ang may numero sa unahan ay halos tiyak na manlalaro. Ito ang unang
  // sinusuri para hindi na maabot ng mga hulang nasa ibaba — mas mabuting
  // magkamali paboran ang tao kaysa tanggalin siya sa listahan.
  if (_numbering.hasMatch(line) || _numberingLoose.hasMatch(line)) return false;

  if (line.endsWith(':')) return true;
  if (_dateish.hasMatch(line)) return true;
  if (_timeish.hasMatch(line)) return true;
  if (_headerWords.hasMatch(line)) return true;

  // Napakahabang linya = pangungusap, hindi pangalan.
  if (line.length > 40) return true;

  return false;
}

int _guestCount(String rawLine) {
  final match = _guestSuffix.firstMatch(rawLine.trim());
  if (match == null) return 0;
  final digits = match.group(1) ?? match.group(2);
  final count = int.tryParse(digits ?? '') ?? 0;
  // Sanity cap — walang nagdadala ng 40 bisita; typo iyon.
  return count.clamp(0, 5);
}

/// Nililinis ang isang linya papuntang pangalan. Null kung walang natira.
ParsedEntry? _parseLine(String rawLine) {
  var working = rawLine.trim();

  working = working.replaceAll(_emoji, ' ');
  working = working.replaceFirst(_numbering, '');
  working = working.replaceFirst(_numberingLoose, '');

  // Kunin muna ang note bago tanggalin ang panaklong.
  String? note;
  final noteMatch = _parenthetical.firstMatch(working);
  if (noteMatch != null) {
    final captured = noteMatch.group(1)?.trim();
    if (captured != null && captured.isNotEmpty) note = captured;
    working = working.replaceAll(_parenthetical, ' ');
  }

  working = working.replaceFirst(_guestSuffix, '');
  working = working.replaceAll(RegExp(r'\s+'), ' ').trim();
  working = working.replaceFirst(_trailingMarks, '').trim();

  if (working.isEmpty) return null;

  // Puro numero o bantas = hindi pangalan.
  if (!RegExp(r'[A-Za-zÀ-ÿÑñ]').hasMatch(working)) return null;

  return ParsedEntry(
    name: working,
    rawLine: rawLine.trim(),
    note: note,
    isGuest: false,
  );
}
