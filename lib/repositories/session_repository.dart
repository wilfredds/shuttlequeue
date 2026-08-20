import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enums.dart';
import '../models/session.dart';
import '../models/synced.dart';
import 'firestore_mappers.dart';

/// Lahat ng Firestore access para sa sessions (at sa courts na kasama nila).
/// Walang ibang layer na tumatawag ng FirebaseFirestore nang direkta.
class SessionRepository {
  SessionRepository(this._db);

  final FirebaseFirestore _db;

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
        courtToCreateMap(label: 'Court $i'),
      );
    }

    // Sadyang hindi ino-await: sa offline, hindi nagre-resolve ang commit
    // hangga't walang network. Naka-apply na ito agad sa local cache.
    unawaited(batch.commit());

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
  }) {
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

    return _sessions.doc(sessionId).update(updates);
  }

  /// Nagdadagdag o nagbabawas ng court nang hindi ginagalaw ang iba.
  Future<void> setCourtCount(String sessionId, int desiredCount) async {
    final courtsRef = _courtsOf(sessionId);
    final existing = await courtsRef.orderBy('label').get();
    final current = existing.docs.length;
    if (current == desiredCount) return;

    final batch = _db.batch();

    if (desiredCount > current) {
      for (var i = current + 1; i <= desiredCount; i++) {
        batch.set(courtsRef.doc(), courtToCreateMap(label: 'Court $i'));
      }
    } else {
      // Tinatanggal ang mga huling court. Ang laro sa court na tinanggal
      // ay hindi basta binubura — ang caller ang dapat sumuri muna
      // (hahawakan ito nang buo sa M3 kasama ng rotation).
      for (final doc in existing.docs.skip(desiredCount)) {
        batch.delete(doc.reference);
      }
    }

    batch.update(_sessions.doc(sessionId), {
      'courtCount': desiredCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
    for (final name in const ['players', 'courts', 'matches']) {
      final snapshot = await sessionRef.collection(name).get();
      refsToDelete.addAll(snapshot.docs.map((doc) => doc.reference));
    }
    refsToDelete.add(sessionRef);

    for (var i = 0; i < refsToDelete.length; i += _batchLimit) {
      final batch = _db.batch();
      final end = (i + _batchLimit).clamp(0, refsToDelete.length);
      for (final ref in refsToDelete.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}

/// Maliit na helper para linawin ang sinasadyang hindi pag-await.
/// (Katulad ng `unawaited` ng package:async — hindi na natin idinagdag
/// ang buong dependency para sa isang linya.)
void unawaited(Future<void> future) {
  future.catchError((Object error) {
    // Ang mga pending write ay nire-retry ng Firestore mismo. Dito lang
    // natin pinipigilan ang unhandled-error na pumatay sa app.
  });
}
