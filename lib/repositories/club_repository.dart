import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/club_member.dart';
import '../models/enums.dart';
import 'deferred_write.dart';
import 'firestore_mappers.dart';

/// Ang club at ang "regulars book" nito.
///
/// Dito nakatira ang datos na **tumatagal sa pagitan ng mga gabi**:
/// naaalalang skill tier, palayaw, at dalang balanse. Ito ang dahilan kung
/// bakit mas mabilis ang pangalawang linggo kaysa sa una.
///
/// PRIVACY (RA 10173): pangalan at skill lang. Walang phone, walang email.
class ClubRepository {
  ClubRepository(this._db, this._auth, {this.onWriteError});

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final WriteErrorReporter? onWriteError;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _clubs => _db.collection('clubs');

  CollectionReference<Map<String, dynamic>> membersOf(String clubId) =>
      _clubs.doc(clubId).collection('members');

  /// Kinukuha ang default club ng QM, o ginagawa ito kung wala pa.
  ///
  /// Isang club muna kada QM sa v1 — pero may sariling ID ito (hindi ang uid)
  /// para kapag kailangan ng pangalawang club sa v2, walang migration.
  Future<String> ensureDefaultClub({
    required String ownerUid,
    required String fallbackName,
  }) async {
    final existing = await _clubs
        .where('ownerUid', isEqualTo: ownerUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    // Ang doc ID ay nabubuo nang lokal, kaya maibabalik natin agad kahit
    // hindi pa naaabot ang server.
    final ref = _clubs.doc();
    fireAndForget(
      ref.set({
        'name': fallbackName,
        'ownerUid': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      onWriteError,
    );
    return ref.id;
  }

  Stream<List<ClubMember>> watchMembers(String clubId) {
    return membersOf(clubId).orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(memberFromDoc).toList(growable: false),
        );
  }

  Future<String> addMember({
    required String clubId,
    required String name,
    required SkillTier skillTier,
    List<String> aliases = const [],
  }) async {
    final ref = membersOf(clubId).doc();
    fireAndForget(
      ref.set(
        memberToCreateMap(
          ownerUid: _uid,
          name: name,
          skillTier: skillTier,
          aliases: aliases,
        ),
      ),
      onWriteError,
    );
    return ref.id;
  }

  /// Ini-update ang naaalalang tier. Tinatawag ito kapag binago ng QM ang
  /// skill ng isang regular — para sa susunod na gabi, tama na agad.
  Future<void> updateMember(
    String clubId,
    String memberId, {
    String? name,
    SkillTier? skillTier,
    List<String>? aliases,
  }) {
    return membersOf(clubId).doc(memberId).update({
      'name': ?name,
      if (skillTier != null) 'skillTier': skillTier.value,
      'aliases': ?aliases,
    });
  }

  /// Nagdaragdag ng palayaw na natutunan sa import (hal. "Kuya Jun" → Jun).
  Future<void> rememberAlias(
    String clubId,
    String memberId,
    String alias,
  ) async {
    fireAndForget(
      membersOf(clubId).doc(memberId).update({
        'aliases': FieldValue.arrayUnion([alias]),
      }),
      onWriteError,
    );
  }

  /// Markahan na dumalo ngayong gabi. Ginagamit ang increment para tama
  /// pa rin kahit maraming pending write habang offline.
  Future<void> recordAttendance(String clubId, String memberId) async {
    fireAndForget(
      membersOf(clubId).doc(memberId).update({
        'sessionsAttended': FieldValue.increment(1),
        'lastPlayedAt': FieldValue.serverTimestamp(),
      }),
      onWriteError,
    );
  }

  /// Utang o sobrang bayad na dala sa susunod na gabi. Positibo = may utang.
  Future<void> adjustBalance(
    String clubId,
    String memberId,
    int deltaCentavos,
  ) async {
    fireAndForget(
      membersOf(clubId).doc(memberId).update({
        'balanceCentavos': FieldValue.increment(deltaCentavos),
      }),
      onWriteError,
    );
  }

  /// Tunay na pagbura — hindi archive. Kailangan ito ng RA 10173 kapag
  /// humiling ang isang manlalaro na alisin ang kanyang datos.
  Future<void> deleteMember(String clubId, String memberId) async {
    fireAndForget(
      membersOf(clubId).doc(memberId).delete(),
      onWriteError,
    );
  }
}
