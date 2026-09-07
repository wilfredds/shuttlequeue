import 'dart:convert';

import '../models/bill_line.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/session.dart';
import '../models/session_player.dart';

/// Ang buong datos ng QM bilang isang file.
///
/// **Bakit ito umiiral.** Ang naka-iskedyul na backup ng Firestore ay para
/// sa bayad na tier. Sa libreng tier, walang backup — kung mabura ang
/// regulars book, wala nang babalikan. Ito ang tanging paraan para
/// makalabas ang datos ng QM sa Firestore at mapunta sa isang bagay na
/// hawak niya mismo.
///
/// Pangalawang layunin: **RA 10173 data portability.** Karapatan ng tao na
/// makuha ang datos na hawak natin, sa hugis na mabubuksan ng ibang
/// programa. JSON iyon, hindi PDF.
///
/// Purong Dart ito — walang Firestore. Ang repository ang nangongolekta,
/// ito ang bumubuo. Kaya nasusubok ang eksaktong laman nang walang network.

/// Ang hugis ng file. Taasan ito kapag nagbago ang istraktura, para
/// malaman ng anumang magbabasa nito kung ano ang inaasahan.
const kExportFormatVersion = 1;

/// Lahat ng nakolekta para sa isang gabi.
class SessionExport {
  const SessionExport({
    required this.session,
    required this.players,
    required this.courts,
    required this.matches,
    required this.bill,
  });

  final Session session;
  final List<SessionPlayer> players;
  final List<Court> courts;
  final List<GameMatch> matches;
  final List<BillLine> bill;
}

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();

Map<String, dynamic> _member(ClubMember m) => {
      'id': m.id,
      'name': m.name,
      'skillTier': m.skillTier.value,
      'aliases': m.aliases,
      'sessionsAttended': m.sessionsAttended,
      // Positibo = may utang sa QM. Sentimo, hindi piso — walang float
      // kahit saan sa pera (spec §4).
      'balanceCentavos': m.balanceCentavos,
      'createdAt': _iso(m.createdAt),
      'lastPlayedAt': _iso(m.lastPlayedAt),
    };

Map<String, dynamic> _player(SessionPlayer p) => {
      'id': p.id,
      'name': p.name,
      'skillTier': p.skillTier.value,
      'gamesPlayed': p.gamesPlayed,
      'waitingSince': _iso(p.waitingSince),
      'status': p.status.value,
      'shuttlesUsed': p.shuttlesUsed,
      'hasPaid': p.hasPaid,
      'createdAt': _iso(p.createdAt),
      // Ang tali sa regulars book. Kailangan ito para maibalik ang ugnayan
      // kapag muling itinayo ang datos mula sa file na ito.
      'memberId': p.memberId,
    };

Map<String, dynamic> _court(Court c) => {
      'id': c.id,
      'label': c.label,
      'status': c.status.value,
      'currentMatchId': c.currentMatchId,
    };

Map<String, dynamic> _match(GameMatch m) => {
      'id': m.id,
      'courtId': m.courtId,
      'teamA': m.teamA,
      'teamB': m.teamB,
      'scoreA': m.scoreA,
      'scoreB': m.scoreB,
      'startedAt': _iso(m.startedAt),
      'endedAt': _iso(m.endedAt),
    };

Map<String, dynamic> _billLine(BillLine b) => {
      'playerId': b.playerId,
      'name': b.name,
      'courtShareCentavos': b.courtShareCentavos,
      'shuttleShareCentavos': b.shuttleShareCentavos,
    };

Map<String, dynamic> _session(SessionExport e) => {
      'id': e.session.id,
      'clubId': e.session.clubId,
      'title': e.session.title,
      'venue': e.session.venue,
      'sessionDate': _iso(e.session.sessionDate),
      'status': e.session.status.value,
      'courtCount': e.session.courtCount,
      'courtFeeCentavos': e.session.courtFeeCentavos,
      'shuttlePriceCentavos': e.session.shuttlePriceCentavos,
      'feeMode': e.session.feeMode.value,
      'billFinalizedAt': _iso(e.session.billFinalizedAt),
      'createdAt': _iso(e.session.createdAt),
      'updatedAt': _iso(e.session.updatedAt),
      'players': e.players.map(_player).toList(),
      'courts': e.courts.map(_court).toList(),
      'matches': e.matches.map(_match).toList(),
      'bill': e.bill.map(_billLine).toList(),
    };

/// Binubuo ang buong export bilang isang Map.
///
/// Pansinin kung ano ang WALA rito: walang email, walang numero ng
/// telepono ng manlalaro, walang password, walang token. Wala ring
/// ownerUid sa loob ng bawat dokumento — paulit-ulit lang iyon at hindi
/// kailangan ng taong magbubukas nito. Pangalan at galaw ng laro lang, na
/// siya ring tanging itinatago ng app (RA 10173).
Map<String, dynamic> buildDataExport({
  required Club? club,
  required List<ClubMember> members,
  required List<SessionExport> sessions,
  required DateTime exportedAt,
  required String appVersion,
}) {
  return {
    'shuttlequeue': {
      'formatVersion': kExportFormatVersion,
      'appVersion': appVersion,
      'exportedAt': _iso(exportedAt),
      'note': 'Backup of one Queue Master. Player names and skill only — '
          'no phone numbers, no emails.',
    },
    'club': club == null
        ? null
        : {
            'id': club.id,
            'name': club.name,
            'gcashNumber': club.gcashNumber,
          },
    'members': members.map(_member).toList(),
    'sessions': sessions.map(_session).toList(),
  };
}

/// Ang file mismo. May indent — babasahin ito ng tao kapag may nasira,
/// at ang isang mahabang linyang JSON ay walang saysay sa gabing iyon.
String encodeDataExport(Map<String, dynamic> export) =>
    const JsonEncoder.withIndent('  ').convert(export);

/// Pangalan ng file: nakaayos ayon sa petsa kapag maraming backup na.
String exportFileName(DateTime exportedAt) {
  String two(int v) => v.toString().padLeft(2, '0');
  final d = exportedAt;
  return 'shuttlequeue-${d.year}-${two(d.month)}-${two(d.day)}.json';
}

/// Maikling buod para sa snackbar: gusto ng QM ng patunay na may nakuha
/// talaga, hindi lang "Done".
String exportSummary(Map<String, dynamic> export) {
  final members = (export['members'] as List).length;
  final sessions = (export['sessions'] as List).length;
  final players = (export['sessions'] as List).fold<int>(
    0,
    (sum, s) => sum + ((s as Map)['players'] as List).length,
  );
  return '$sessions sessions · $players player rows · $members regulars';
}
