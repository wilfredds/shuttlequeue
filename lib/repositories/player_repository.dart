import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enums.dart';
import '../models/session_player.dart';
import '../models/synced.dart';
import 'firestore_mappers.dart';

/// Isang bagong manlalarong idadagdag — galing man sa paste o sa manual add.
class NewPlayer {
  const NewPlayer({
    required this.name,
    this.skillTier = SkillTier.intermediate,
    this.memberId,
  });

  final String name;
  final SkillTier skillTier;
  final String? memberId;
}

class PlayerRepository {
  PlayerRepository(this._db);

  final FirebaseFirestore _db;

  static const _batchLimit = 400;

  CollectionReference<Map<String, dynamic>> _playersOf(String sessionId) =>
      _db.collection('sessions').doc(sessionId).collection('players');

  Stream<Synced<List<SessionPlayer>>> watchPlayers(String sessionId) {
    return _playersOf(sessionId).snapshots().map((snapshot) {
      final players =
          snapshot.docs.map(playerFromDoc).toList(growable: false);
      // Inaayos sa client, hindi sa query: iniiwasan ang dagdag na index at
      // pareho ang resulta offline (maliit lang ang listahan — 20-40 tao).
      final sorted = [...players]..sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return byName;
        });
      return Synced(
        data: sorted,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        isFromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  /// Bulk add mula sa import. Isang batch para hindi kalahati lang ang pumasok.
  Future<void> addPlayers(String sessionId, List<NewPlayer> players) async {
    if (players.isEmpty) return;

    final now = DateTime.now();
    final ref = _playersOf(sessionId);

    for (var i = 0; i < players.length; i += _batchLimit) {
      final batch = _db.batch();
      final end = (i + _batchLimit).clamp(0, players.length);
      for (final player in players.sublist(i, end)) {
        batch.set(
          ref.doc(),
          playerToCreateMap(
            name: player.name,
            skillTier: player.skillTier,
            gamesPlayed: 0,
            waitingSince: now,
            memberId: player.memberId,
          ),
        );
      }
      await batch.commit();
    }
  }

  /// Late arrival: pumapasok na may `gamesPlayed` na katumbas ng pinakamababa
  /// sa mga aktibong manlalaro.
  ///
  /// Kung 0 ang ibibigay natin, uunahin siya ng algorithm sa lahat — hindi
  /// patas sa mga naghihintay mula alas-8. Kung kasing-taas naman ng iba,
  /// baka hindi na siya makalaro. Ang minimum ang tamang gitna (spec §5).
  Future<void> addLateArrival(
    String sessionId,
    NewPlayer player,
    List<SessionPlayer> currentPlayers,
  ) {
    final active = currentPlayers
        .where((p) => p.status != PlayerStatus.left)
        .map((p) => p.gamesPlayed);

    final baseline = active.isEmpty
        ? 0
        : active.reduce((a, b) => a < b ? a : b);

    return _playersOf(sessionId).doc().set(
          playerToCreateMap(
            name: player.name,
            skillTier: player.skillTier,
            gamesPlayed: baseline,
            waitingSince: DateTime.now(),
            memberId: player.memberId,
          ),
        );
  }

  Future<void> updatePlayer(
    String sessionId,
    String playerId, {
    String? name,
    SkillTier? skillTier,
    PlayerStatus? status,
    bool? hasPaid,
  }) {
    return _playersOf(sessionId).doc(playerId).update({
      'name': ?name,
      if (skillTier != null) 'skillTier': skillTier.value,
      if (status != null) 'status': status.value,
      'hasPaid': ?hasPaid,
      // Kapag bumalik sa pila, ngayon nagsisimula ang paghihintay niya.
      if (status == PlayerStatus.queued)
        'waitingSince': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Bilang ng shuttle na nagamit. Increment para tama kahit offline.
  Future<void> adjustShuttles(String sessionId, String playerId, int delta) {
    return _playersOf(sessionId).doc(playerId).update({
      'shuttlesUsed': FieldValue.increment(delta),
    });
  }

  Future<void> removePlayer(String sessionId, String playerId) {
    return _playersOf(sessionId).doc(playerId).delete();
  }

  /// Para sa undo ng pagtanggal: ibinabalik ang buong laman ng player.
  /// Bagong document ID ito — hindi na kayang ibalik ang luma — pero
  /// nananatili ang lahat ng bilang, kaya buo pa rin ang fairness.
  Future<void> restorePlayer(String sessionId, SessionPlayer player) {
    return _playersOf(sessionId).doc().set({
      'name': player.name,
      'skillTier': player.skillTier.value,
      'gamesPlayed': player.gamesPlayed,
      'waitingSince': Timestamp.fromDate(player.waitingSince),
      'status': player.status.value,
      'shuttlesUsed': player.shuttlesUsed,
      'hasPaid': player.hasPaid,
      'memberId': player.memberId,
      'createdAt': Timestamp.fromDate(player.createdAt),
    });
  }
}
