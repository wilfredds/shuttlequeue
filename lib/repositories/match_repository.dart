import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/court.dart';
import '../models/enums.dart';
import '../models/match.dart';
import '../models/synced.dart';
import 'firestore_mappers.dart';

/// Courts at matches — ang mismong pag-ikot ng laro.
///
/// Bawat pagbabago ng estado ay **isang batch**. Kalahating naaplay na
/// rotation (naka-playing ang court pero naka-queued pa rin ang mga tao)
/// ang pinakamabilis na paraan para masira ang tiwala ng QM sa app.
class MatchRepository {
  MatchRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _session(String sessionId) =>
      _db.collection('sessions').doc(sessionId);

  Stream<Synced<List<Court>>> watchCourts(String sessionId) {
    return _session(sessionId).collection('courts').snapshots().map((snapshot) {
      final courts = snapshot.docs.map(courtFromDoc).toList()
        ..sort((a, b) => _naturalCompare(a.label, b.label));
      return Synced(
        data: courts,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        isFromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  /// Lahat ng laro ngayong gabi. Ginagamit ng no-repeat rotation at,
  /// mamaya, ng night recap cards.
  Stream<List<GameMatch>> watchMatches(String sessionId) {
    return _session(sessionId)
        .collection('matches')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(matchFromDoc).toList());
  }

  /// Simulan ang laro: gumagawa ng match, ino-okupa ang court, at
  /// nilalagay sa "playing" ang apat — lahat sa iisang batch.
  Future<String> startMatch({
    required String sessionId,
    required String courtId,
    required List<String> teamA,
    required List<String> teamB,
  }) async {
    final sessionRef = _session(sessionId);
    final matchRef = sessionRef.collection('matches').doc();
    final batch = _db.batch();

    batch.set(matchRef, {
      'ownerUid': _uid,
      'courtId': courtId,
      'teamA': teamA,
      'teamB': teamB,
      'scoreA': null,
      'scoreB': null,
      'startedAt': Timestamp.fromDate(DateTime.now()),
      'endedAt': null,
    });

    batch.update(sessionRef.collection('courts').doc(courtId), {
      'status': CourtStatus.playing.value,
      'currentMatchId': matchRef.id,
    });

    for (final playerId in [...teamA, ...teamB]) {
      batch.update(sessionRef.collection('players').doc(playerId), {
        'status': PlayerStatus.playing.value,
      });
    }

    await batch.commit();
    return matchRef.id;
  }

  /// Tapos na ang laro: +1 ang bilang ng bawat isa, muling nagsisimula ang
  /// paghihintay nila, at bakante na ang court.
  ///
  /// Ang `FieldValue.increment` ay sinasadya — commutative ito, kaya tama
  /// pa rin ang bilang kahit maraming pending write habang offline.
  Future<void> endMatch({
    required String sessionId,
    required GameMatch match,
    int? scoreA,
    int? scoreB,
  }) async {
    final sessionRef = _session(sessionId);
    final now = DateTime.now();
    final batch = _db.batch();

    batch.update(sessionRef.collection('matches').doc(match.id), {
      'endedAt': Timestamp.fromDate(now),
      'scoreA': scoreA,
      'scoreB': scoreB,
    });

    batch.update(sessionRef.collection('courts').doc(match.courtId), {
      'status': CourtStatus.free.value,
      'currentMatchId': null,
    });

    for (final playerId in match.allPlayerIds) {
      batch.update(sessionRef.collection('players').doc(playerId), {
        'gamesPlayed': FieldValue.increment(1),
        'waitingSince': Timestamp.fromDate(now),
        'status': PlayerStatus.queued.value,
      });
    }

    await batch.commit();
  }

  /// Ang eksaktong kabaligtaran ng [endMatch] — R-03.
  ///
  /// Kailangang perpekto ang pagbawi: kung maiwan ang dagdag na +1 sa
  /// gamesPlayed, sisira ito sa buong fairness ng gabi, at ang bilang na
  /// iyon ang tanging batayan ng "sino ang susunod".
  Future<void> undoEndMatch({
    required String sessionId,
    required GameMatch match,
  }) async {
    final sessionRef = _session(sessionId);
    final batch = _db.batch();

    batch.update(sessionRef.collection('matches').doc(match.id), {
      'endedAt': null,
      'scoreA': null,
      'scoreB': null,
    });

    batch.update(sessionRef.collection('courts').doc(match.courtId), {
      'status': CourtStatus.playing.value,
      'currentMatchId': match.id,
    });

    for (final playerId in match.allPlayerIds) {
      batch.update(sessionRef.collection('players').doc(playerId), {
        'gamesPlayed': FieldValue.increment(-1),
        'waitingSince': Timestamp.fromDate(match.startedAt),
        'status': PlayerStatus.playing.value,
      });
    }

    await batch.commit();
  }

  /// Kanselahin ang laro na parang hindi ito nangyari — walang dagdag na
  /// bilang, babalik sa pila ang apat. Para sa maling pindot ng "Next".
  Future<void> cancelMatch({
    required String sessionId,
    required GameMatch match,
  }) async {
    final sessionRef = _session(sessionId);
    final now = DateTime.now();
    final batch = _db.batch();

    batch.delete(sessionRef.collection('matches').doc(match.id));

    batch.update(sessionRef.collection('courts').doc(match.courtId), {
      'status': CourtStatus.free.value,
      'currentMatchId': null,
    });

    for (final playerId in match.allPlayerIds) {
      batch.update(sessionRef.collection('players').doc(playerId), {
        'status': PlayerStatus.queued.value,
        'waitingSince': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }
}

/// "Court 2" bago ang "Court 10" — hindi tulad ng plain string sort.
int _naturalCompare(String a, String b) {
  final numA = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
  final numB = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
  if (numA != null && numB != null) return numA.compareTo(numB);
  return a.compareTo(b);
}
