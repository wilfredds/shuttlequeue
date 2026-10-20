import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/club.dart';
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

  /// Tingnan ang ownedQuery sa deferred_write.dart — kailangan ng bawat
  /// collection query ang salaang ito para hindi tanggihan ng rules.
  Query<Map<String, dynamic>> _ownedQuery(
    Query<Map<String, dynamic>> collection,
  ) =>
      ownedQuery(collection, _uid);

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
    // Cache muna: mabilis, at gumagana kahit walang signal.
    final cached = await _clubsOwnedBy(ownerUid, cacheOnly);

    // ...pero HINDI sapat ang cache dito, at ito ang natutunan natin sa
    // mahirap na paraan. Kapag bagong device, bagong browser, o na-clear
    // ang storage, walang laman ang cache — kahit may club na pala sa
    // server. Kung basta tayo gagawa ng bago, maiiwan ang luma: mawawala
    // ang buong regulars book, ang mga dalang utang, at ang GCash number
    // ng QM, at hindi niya malalaman kung bakit.
    //
    // Masahol pa: kapag ang cache ay may HAWAK na ng naulit na club,
    // habambuhay na iyon ang gagamitin — hindi na natin makikita ang totoo.
    // Kaya tinatanong natin ang server kahit may laman ang cache.
    //
    // Isang beses lang ito kada buksan ng app (FutureProvider ang
    // defaultClubId), kaya isang read lang ang dagdag — wala iyon.
    //
    // May hangganan ang paghihintay (R-15: huwag i-hang ang QM):
    // maikli kung may sagot na tayo sa cache, mas mahaba kung wala.
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? remote;
    try {
      remote = await _clubsOwnedBy(ownerUid, null).timeout(
        cached.isEmpty
            ? const Duration(seconds: 5)
            : const Duration(seconds: 2),
      );
    } catch (_) {
      // Offline, mabagal, o tinanggihan — ang cache na ang bahala.
    }

    // Mas totoo ang server kapag nakasagot ito; kung hindi, cache muna.
    final found = remote ?? cached;
    final fromCache = remote == null;

    // Ang karaniwang daan: iisa ang club, walang nadoble. Dito napupunta
    // ang halos lahat ng gabi.
    if (found.length == 1) return found.first.id;

    if (found.isNotEmpty) return _resolveDuplicates(found, fromCache);

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

  /// Walang `limit(1)` dito nang sinasadya: kung may nadoblang club, gusto
  /// nating MAKITA silang lahat para makapili tayo nang parehong-pareho sa
  /// bawat device. Tingnan ang pickPrimaryClub.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _clubsOwnedBy(
    String ownerUid,
    GetOptions? source,
  ) async {
    final snapshot =
        await _clubs.where('ownerUid', isEqualTo: ownerUid).get(source);
    return snapshot.docs;
  }

  /// Nadoble ang club. Piliin ang totoo, at sagipin ang GCash number.
  ///
  /// Dito lang tayo nagbabasa ng miyembro — sa sirang kalagayan lang, hindi
  /// sa karaniwang gabi. Kung saan natin nakita ang mga club, doon din natin
  /// bibilangin ang miyembro: kapag galing sa server ang listahan, malamig
  /// ang cache, kaya SERO ang mabibilang natin doon sa lahat — at mali ang
  /// pagpili.
  Future<String> _resolveDuplicates(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clubs,
    bool fromCache,
  ) async {
    final source = fromCache ? cacheOnly : null;
    final candidates = <ClubCandidate>[];

    for (final club in clubs) {
      var memberCount = 0;
      try {
        final members = await _ownedQuery(membersOf(club.id))
            .get(source)
            .timeout(const Duration(seconds: 5));
        memberCount = members.docs.length;
      } catch (_) {
        // Hindi mabilang — mananatiling sero. Ang edad at ID na ang bahala.
      }

      final createdAt = club.data()['createdAt'];
      final gcash = club.data()['gcashNumber'];
      candidates.add((
        id: club.id,
        createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
        memberCount: memberCount,
        gcashNumber: gcash is String ? gcash : null,
      ));
    }

    final choice = pickPrimaryClub(candidates)!;

    // Ibalik ang naulilang numero. Fire-and-forget: hindi hihintayin ng QM
    // ang pagkukumpuni, at kung mabigo man, subok ulit sa susunod na buksan.
    final adopt = choice.adoptGcash;
    if (adopt != null) {
      fireAndForget(
        _clubs.doc(choice.id).update({'gcashNumber': adopt}),
        onWriteError,
      );
    }

    // SADYANG hindi natin binubura ang mga naulit. Ang pagbura ay hindi na
    // mababawi, at kung nagkamali ang bilang natin ng miyembro, datos ng QM
    // ang mawawala. Libre naman ang dalawang tabi-tabing doc.
    return choice.id;
  }

  Stream<Club?> watchClub(String clubId) {
    return _clubs.doc(clubId).snapshots().map(
          (doc) => doc.exists ? clubFromDoc(doc) : null,
        );
  }

  /// Ang numerong padadalhan ng bayad ng mga manlalaro.
  ///
  /// Nakatago ito sa club, hindi naka-hardcode sa app: iba ang numero ng
  /// bawat QM, at kapag ang coach na ang gumamit nito, sa kanya dapat
  /// mapunta ang pera.
  Future<void> setGcashNumber(String clubId, String? number) async {
    fireAndForget(
      _clubs.doc(clubId).update({'gcashNumber': number}),
      onWriteError,
    );
  }

  /// Walang `orderBy` dito nang sinasadya. Ang query ay kailangang
  /// may `where(ownerUid)` para papasa sa rules; ang pagsasama ng where
  /// at orderBy sa magkaibang field ay mangangailangan ng composite index.
  /// Maliit lang ang listahan ng regulars, kaya sa client na lang tayo
  /// mag-aayos — pareho ang resulta, at walang dagdag na index.
  Stream<List<ClubMember>> watchMembers(String clubId) {
    return _ownedQuery(membersOf(clubId)).snapshots().map((snapshot) {
      final members = snapshot.docs.map(memberFromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return members;
    });
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
    int? avatarSeed,
  }) {
    return membersOf(clubId).doc(memberId).update({
      'name': ?name,
      if (skillTier != null) 'skillTier': skillTier.value,
      'aliases': ?aliases,
      // Ang mukhang pinili ng QM ngayong gabi ay naaalala sa susunod.
      // Dito ang tamang lugar nito: ang regulars book ang may hawak ng
      // kung ano ang tumatagal sa pagitan ng mga gabi.
      'avatarSeed': ?avatarSeed,
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
