/// Iisang lugar lang ang nakakaalam ng hugis ng data sa Firestore.
/// Kung magbago ang field name, dito lang hahanapin — hindi kalat sa screens.
///
/// Panuntunan: **huwag mag-throw kapag pangit ang data.** Mas mabuting may
/// isang session na may maling default kaysa hindi mabuksan ng QM ang app sa
/// gitna ng gabi. Lahat ng reader dito ay may ligtas na fallback.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill_line.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import '../models/court.dart';
import '../models/enums.dart';
import '../models/match.dart';
import '../models/session.dart';
import '../models/session_player.dart';

// ---------------------------------------------------------------------------
// Ligtas na readers
// ---------------------------------------------------------------------------

DateTime _readDate(Object? value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  // Offline, ang serverTimestamp ay pansamantalang null sa local cache.
  return fallback ?? DateTime.now();
}

DateTime? _readNullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

int? _readNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String _readString(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

bool _readBool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

Session sessionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final created = _readDate(data['createdAt']);

  return Session(
    id: doc.id,
    ownerUid: _readString(data['ownerUid']),
    clubId: _readString(data['clubId']),
    title: _readString(data['title']),
    venue: _readString(data['venue']),
    sessionDate: _readDate(data['sessionDate'], fallback: created),
    status: SessionStatus.fromValue(data['status'] as String?),
    courtCount: _readInt(data['courtCount'], fallback: 1),
    courtFeeCentavos: _readInt(data['courtFeeCentavos']),
    shuttlePriceCentavos: _readInt(data['shuttlePriceCentavos']),
    feeMode: FeeMode.fromValue(data['feeMode'] as String?),
    createdAt: created,
    updatedAt: _readDate(data['updatedAt'], fallback: created),
    billFinalizedAt: _readNullableDate(data['billFinalizedAt']),
  );
}

/// Para sa create. serverTimestamp ang createdAt/updatedAt — offline,
/// null muna ito sa cache tapos pinupunan pagka-sync.
Map<String, Object?> sessionToCreateMap({
  required String ownerUid,
  required String clubId,
  required String title,
  required String venue,
  required DateTime sessionDate,
  required int courtCount,
  required int courtFeeCentavos,
  required int shuttlePriceCentavos,
  required FeeMode feeMode,
}) {
  return {
    'ownerUid': ownerUid,
    'clubId': clubId,
    'title': title,
    'venue': venue,
    'sessionDate': Timestamp.fromDate(sessionDate),
    'status': SessionStatus.setup.value,
    'courtCount': courtCount,
    'courtFeeCentavos': courtFeeCentavos,
    'shuttlePriceCentavos': shuttlePriceCentavos,
    'feeMode': feeMode.value,
    'billFinalizedAt': null,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
// BillLine — mga naka-freeze na halaga
// ---------------------------------------------------------------------------

BillLine billLineFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return BillLine(
    // Ang document ID ay ang player ID — isang linya kada manlalaro.
    playerId: doc.id,
    name: _readString(data['name']),
    courtShareCentavos: _readInt(data['courtShareCentavos']),
    shuttleShareCentavos: _readInt(data['shuttleShareCentavos']),
  );
}

Map<String, Object?> billLineToMap(BillLine line, {required String ownerUid}) {
  return {
    'ownerUid': ownerUid,
    'name': line.name,
    'courtShareCentavos': line.courtShareCentavos,
    'shuttleShareCentavos': line.shuttleShareCentavos,
  };
}

// ---------------------------------------------------------------------------
// SessionPlayer
// ---------------------------------------------------------------------------

SessionPlayer playerFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final created = _readDate(data['createdAt']);

  return SessionPlayer(
    id: doc.id,
    name: _readString(data['name']),
    skillTier: SkillTier.fromValue(data['skillTier'] as String?),
    gamesPlayed: _readInt(data['gamesPlayed']),
    waitingSince: _readDate(data['waitingSince'], fallback: created),
    status: PlayerStatus.fromValue(data['status'] as String?),
    shuttlesUsed: _readInt(data['shuttlesUsed']),
    hasPaid: _readBool(data['hasPaid']),
    createdAt: created,
    memberId: data['memberId'] as String?,
  );
}

Map<String, Object?> playerToCreateMap({
  required String ownerUid,
  required String name,
  required SkillTier skillTier,
  required int gamesPlayed,
  required DateTime waitingSince,
  String? memberId,
}) {
  return {
    // Naka-stamp ang may-ari sa mismong dokumento. Dati, tinitingnan ng
    // rules ang parent session sa pamamagitan ng get() — pero sa loob ng
    // isang batch, wala pa ang parent na iyon, kaya tinatanggihan ang
    // BUONG batch at nawawala ang bagong session sa harap ng QM.
    'ownerUid': ownerUid,
    'name': name,
    'skillTier': skillTier.value,
    'gamesPlayed': gamesPlayed,
    'waitingSince': Timestamp.fromDate(waitingSince),
    'status': PlayerStatus.queued.value,
    'shuttlesUsed': 0,
    'hasPaid': false,
    'memberId': memberId,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
// Court at Match
// ---------------------------------------------------------------------------

Court courtFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Court(
    id: doc.id,
    label: _readString(data['label'], fallback: 'Court'),
    status: CourtStatus.fromValue(data['status'] as String?),
    currentMatchId: data['currentMatchId'] as String?,
  );
}

Map<String, Object?> courtToCreateMap({
  required String ownerUid,
  required String label,
}) {
  return {
    'ownerUid': ownerUid,
    'label': label,
    'status': CourtStatus.free.value,
    'currentMatchId': null,
  };
}

GameMatch matchFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return GameMatch(
    id: doc.id,
    courtId: _readString(data['courtId']),
    teamA: _readStringList(data['teamA']),
    teamB: _readStringList(data['teamB']),
    scoreA: _readNullableInt(data['scoreA']),
    scoreB: _readNullableInt(data['scoreB']),
    startedAt: _readDate(data['startedAt']),
    endedAt: _readNullableDate(data['endedAt']),
  );
}

// ---------------------------------------------------------------------------
// Club
// ---------------------------------------------------------------------------

Club clubFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Club(
    id: doc.id,
    name: _readString(data['name']),
    ownerUid: _readString(data['ownerUid']),
    gcashNumber: data['gcashNumber'] as String?,
  );
}

// ---------------------------------------------------------------------------
// ClubMember — ang regulars book
// ---------------------------------------------------------------------------

ClubMember memberFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return ClubMember(
    id: doc.id,
    name: _readString(data['name']),
    skillTier: SkillTier.fromValue(data['skillTier'] as String?),
    aliases: _readStringList(data['aliases']),
    balanceCentavos: _readInt(data['balanceCentavos']),
    sessionsAttended: _readInt(data['sessionsAttended']),
    createdAt: _readDate(data['createdAt']),
    lastPlayedAt: _readNullableDate(data['lastPlayedAt']),
  );
}

Map<String, Object?> memberToCreateMap({
  required String ownerUid,
  required String name,
  required SkillTier skillTier,
  List<String> aliases = const [],
}) {
  return {
    'ownerUid': ownerUid,
    'name': name,
    'skillTier': skillTier.value,
    'aliases': aliases,
    'balanceCentavos': 0,
    'sessionsAttended': 0,
    'lastPlayedAt': null,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
