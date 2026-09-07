import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/club.dart';
import '../services/data_export.dart';
import 'deferred_write.dart';
import 'firestore_mappers.dart';

/// Kinokolekta ang LAHAT ng datos ng QM para sa isang backup file.
///
/// Ito lang ang lugar sa app na sinasadyang nagbabasa ng marami nang
/// sabay-sabay. Ligtas iyon dahil hindi ito tumatakbo sa gitna ng gabi —
/// pinipindot ito ng QM nang tahasan, minsan lang, at may spinner.
///
/// Bilang ng read: humigit-kumulang (bilang ng gabi x 4) + 2. Sa isang
/// buong season na tatlumpung gabi, mga 2,500 read — malayo pa sa 50,000
/// kada araw na libre (R-12). Hindi lang ito dapat ilagay sa isang loop.
class ExportRepository {
  ExportRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection('clubs');

  /// Sinasadyang WALANG `Source.cache` dito. Sa lahat ng ibang basa sa app,
  /// cache muna — pero ito ay backup: ang gusto natin ay ang pinakabago at
  /// pinakakumpletong datos. Kapag walang signal, ang SDK na mismo ang
  /// babagsak pabalik sa cache, kaya may nakukuha pa rin ang QM.
  Future<Map<String, dynamic>> gather({
    required String ownerUid,
    required String? clubId,
    required String appVersion,
    DateTime? now,
  }) async {
    Club? club;
    if (clubId != null) {
      final doc = await _clubs.doc(clubId).get();
      if (doc.exists) club = clubFromDoc(doc);
    }

    final memberDocs = clubId == null
        ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        : (await ownedQuery(_clubs.doc(clubId).collection('members'), ownerUid)
                .get())
            .docs;

    final sessionDocs = (await ownedQuery(_sessions, ownerUid).get()).docs;

    final sessions = <SessionExport>[];
    for (final doc in sessionDocs) {
      final ref = _sessions.doc(doc.id);

      // Bawat subcollection ay dapat may salaang ownerUid — hindi filter
      // ang rules, kaya tinatanggihan ang query na walang ganito
      // (tingnan ang deferred_write.dart).
      final players = await ownedQuery(ref.collection('players'), ownerUid).get();
      final courts = await ownedQuery(ref.collection('courts'), ownerUid).get();
      final matches = await ownedQuery(ref.collection('matches'), ownerUid).get();
      final bill = await ownedQuery(ref.collection('bill'), ownerUid).get();

      sessions.add(
        SessionExport(
          session: sessionFromDoc(doc),
          players: players.docs.map(playerFromDoc).toList(),
          courts: courts.docs.map(courtFromDoc).toList(),
          matches: matches.docs.map(matchFromDoc).toList(),
          bill: bill.docs.map(billLineFromDoc).toList(),
        ),
      );
    }

    // Pinakabago muna — ganito rin ang pagkakasunod sa dashboard.
    sessions.sort(
      (a, b) => b.session.sessionDate.compareTo(a.session.sessionDate),
    );

    return buildDataExport(
      club: club,
      members: memberDocs.map(memberFromDoc).toList(),
      sessions: sessions,
      exportedAt: now ?? DateTime.now(),
      appVersion: appVersion,
    );
  }
}
