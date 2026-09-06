import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/bill_line.dart';
import '../models/enums.dart';
import '../models/session.dart';
import '../models/synced.dart';
import 'deferred_write.dart';
import 'firestore_mappers.dart';

/// Lahat ng Firestore access para sa sessions (at sa courts na kasama nila).
/// Walang ibang layer na tumatawag ng FirebaseFirestore nang direkta.
class SessionRepository {
  SessionRepository(this._db, this._auth, {this.onWriteError});

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Tinatawag kapag nabigo ang isang sulat na hindi hinintay ng UI.
  /// Kung wala nito, tahimik na nawawala ang datos — at iyon ang
  /// pinakamasamang uri ng bug (tingnan ang sync_error_provider.dart).
  final WriteErrorReporter? onWriteError;

  /// Isinusulat sa bawat child document para hindi na kailangang tanungin
  /// ng rules ang parent. Tingnan ang komento sa firestore_mappers.dart.
  String get _uid => _auth.currentUser?.uid ?? '';

  /// Tingnan ang ownedQuery sa deferred_write.dart — kailangan ng bawat
  /// collection query ang salaang ito para hindi tanggihan ng rules.
  Query<Map<String, dynamic>> _ownedQuery(
    Query<Map<String, dynamic>> collection,
  ) =>
      ownedQuery(collection, _uid);

  /// Firestore batch limit ay 500 writes. Nag-iiwan tayo ng allowance
  /// para sa parent doc at sa anumang madagdag mamaya.
  static const _batchLimit = 400;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  CollectionReference<Map<String, dynamic>> _courtsOf(String sessionId) =>
      _sessions.doc(sessionId).collection('courts');

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  /// Mga session ng isang QM, pinakabago muna.
  ///
  /// Isang listener lang para sa buong listahan — hindi isa kada row.
  /// Ito ang pumipigil sa pag-ubos ng 50k reads/day na free-tier quota (R-12).
  Stream<Synced<List<Session>>> watchSessions(String ownerUid) {
    return _sessions
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => Synced(
            data: snapshot.docs.map(sessionFromDoc).toList(growable: false),
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  Stream<Session?> watchSession(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map(
          (doc) => doc.exists ? sessionFromDoc(doc) : null,
        );
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  /// Gumagawa ng session **kasama ang mga court nito sa iisang batch**.
  ///
  /// Sinasadyang atomic: kung mahati ito, magkakaroon tayo ng session na
  /// walang court — at hindi magagamit ang buong rotation screen.
  ///
  /// Hindi ito naghihintay ng server. Offline, agad na lumalabas ang session
  /// mula sa local cache; hindi kailanman naka-block ang QM (R-15).
  Future<String> createSession({
    required String ownerUid,
    required String clubId,
    required String title,
    required String venue,
    required DateTime sessionDate,
    required int courtCount,
    required int courtFeeCentavos,
    required int shuttlePriceCentavos,
    required FeeMode feeMode,
  }) async {
    final sessionRef = _sessions.doc();
    final batch = _db.batch();

    batch.set(
      sessionRef,
      sessionToCreateMap(
        ownerUid: ownerUid,
        clubId: clubId,
        title: title,
        venue: venue,
        sessionDate: sessionDate,
        courtCount: courtCount,
        courtFeeCentavos: courtFeeCentavos,
        shuttlePriceCentavos: shuttlePriceCentavos,
        feeMode: feeMode,
      ),
    );

    for (var i = 1; i <= courtCount; i++) {
      batch.set(
        sessionRef.collection('courts').doc(),
        courtToCreateMap(ownerUid: ownerUid, label: 'Court $i'),
      );
    }

    // Sadyang hindi ino-await: sa offline, hindi nagre-resolve ang commit
    // hangga't walang network. Naka-apply na ito agad sa local cache.
    fireAndForget(batch.commit(), onWriteError);

    return sessionRef.id;
  }

  Future<void> updateSession(
    String sessionId, {
    String? title,
    String? venue,
    DateTime? sessionDate,
    SessionStatus? status,
    int? courtFeeCentavos,
    int? shuttlePriceCentavos,
    FeeMode? feeMode,
  }) async {
    final updates = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
      // `?value` = laktawan ang entry kapag null. Ang hindi binanggit na
      // field ay hindi nagagalaw sa Firestore — partial update lang ito.
      'title': ?title,
      'venue': ?venue,
      if (sessionDate != null) 'sessionDate': Timestamp.fromDate(sessionDate),
      if (status != null) 'status': status.value,
      'courtFeeCentavos': ?courtFeeCentavos,
      'shuttlePriceCentavos': ?shuttlePriceCentavos,
      if (feeMode != null) 'feeMode': feeMode.value,
    };

    fireAndForget(_sessions.doc(sessionId).update(updates), onWriteError);
  }

  /// Nagdadagdag o nagbabawas ng court nang hindi ginagalaw ang iba.
  Future<void> setCourtCount(String sessionId, int desiredCount) async {
    final courtsRef = _courtsOf(sessionId);
    final existing = await _ownedQuery(courtsRef).get(cacheOnly);

    // HINDI pwedeng orderBy('label') dito: string ang paghahambing, kaya
    // ang "Court 10" ay nauuna sa "Court 2". Kapag binawasan ang bilang,
    // maling court ang mabubura. Sa client tayo nag-aayos, gamit ang
    // parehong natural sort na ginagamit ng courts screen.
    final sorted = [...existing.docs]..sort(
        (a, b) => naturalCompare(
          (a.data()['label'] as String?) ?? '',
          (b.data()['label'] as String?) ?? '',
        ),
      );

    final current = sorted.length;
    if (current == desiredCount) return;

    final batch = _db.batch();

    if (desiredCount > current) {
      for (var i = current + 1; i <= desiredCount; i++) {
        batch.set(
          courtsRef.doc(),
          courtToCreateMap(ownerUid: _uid, label: 'Court $i'),
        );
      }
    } else {
      // Ang court na may kasalukuyang laro ay hindi binubura — mawawala
      // ang laro at maiiwang "playing" ang apat na tao, na hindi na
      // kailanman babalik sa pila. Nilalaktawan natin sila; kapag natapos
      // ang laro, pwedeng ulitin ng QM.
      for (final doc in sorted.skip(desiredCount)) {
        final isPlaying = doc.data()['currentMatchId'] != null;
        if (isPlaying) continue;
        batch.delete(doc.reference);
      }
    }

    batch.update(_sessions.doc(sessionId), {
      'courtCount': desiredCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    fireAndForget(batch.commit(), onWriteError);
  }

  // -------------------------------------------------------------------------
  // Bayarin — R-09
  // -------------------------------------------------------------------------

  Stream<List<BillLine>> watchBill(String sessionId) {
    return _ownedQuery(_sessions.doc(sessionId).collection('bill'))
        .snapshots()
        .map((snapshot) => snapshot.docs.map(billLineFromDoc).toList());
  }

  /// Ini-freeze ang bayarin: isinusulat ang bawat halaga bilang datos.
  ///
  /// Pagkatapos nito, hindi na nagbabago ang singil kahit may dumating pang
  /// late o magpalit ng fee mode. Ito ang pumipigil sa sitwasyong may hawak
  /// nang pera ang QM na hindi tugma sa nasa screen (R-09).
  Future<void> finalizeBill(String sessionId, List<BillLine> lines) async {
    final sessionRef = _sessions.doc(sessionId);
    final billRef = sessionRef.collection('bill');
    final batch = _db.batch();

    for (final line in lines) {
      // Player ID ang document ID — isang linya lang kada manlalaro,
      // at idempotent ang muling pag-finalize.
      batch.set(billRef.doc(line.playerId), billLineToMap(line, ownerUid: _uid));
    }

    // Ang pag-lock ng bayarin ang tunay na hudyat na tapos na ang gabi —
    // iyon ang ginagawa ng QM bago mangolekta. Walang dagdag na pindot.
    batch.update(sessionRef, {
      'billFinalizedAt': FieldValue.serverTimestamp(),
      'status': SessionStatus.ended.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    fireAndForget(batch.commit(), onWriteError);
  }

  /// Binubuksan muli ang bayarin — sinasadyang may babala sa UI.
  Future<void> reopenBill(String sessionId) async {
    final sessionRef = _sessions.doc(sessionId);
    final existing =
        await _ownedQuery(sessionRef.collection('bill')).get(cacheOnly);

    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    // Binuksan muli ang bayarin, kaya hindi pa pala tapos ang gabi.
    batch.update(sessionRef, {
      'billFinalizedAt': null,
      'status': SessionStatus.live.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    fireAndForget(batch.commit(), onWriteError);
  }

  /// Buong pagbura ng session at ng lahat ng laman nito.
  ///
  /// **Hindi cascade ang Firestore** — kapag binura ang parent doc, nananatili
  /// ang subcollections bilang "orphans" na hindi na maaabot. Kaya kailangang
  /// isa-isahin. Kailangan din ito para sa RA 10173: kapag sinabi nating
  /// "delete session", dapat totoong nabubura ang mga pangalan.
  Future<void> deleteSession(String sessionId) async {
    final sessionRef = _sessions.doc(sessionId);

    final refsToDelete = <DocumentReference<Map<String, dynamic>>>[];
    for (final name in const ['players', 'courts', 'matches', 'bill']) {
      final snapshot =
          await _ownedQuery(sessionRef.collection(name)).get(cacheOnly);
      refsToDelete.addAll(snapshot.docs.map((doc) => doc.reference));
    }
    refsToDelete.add(sessionRef);

    for (var i = 0; i < refsToDelete.length; i += _batchLimit) {
      final batch = _db.batch();
      final end = (i + _batchLimit).clamp(0, refsToDelete.length);
      for (final ref in refsToDelete.sublist(i, end)) {
        batch.delete(ref);
      }
      fireAndForget(batch.commit(), onWriteError);
    }
  }
}
