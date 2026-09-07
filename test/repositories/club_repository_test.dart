import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/repositories/club_repository.dart';

/// Ang buong daanan ng `ensureDefaultClub` — hindi lang ang pure picker.
///
/// Isinulat ito dahil may TOTOONG pinsala: isang QM, tatlong club, at hati
/// ang kanyang kasaysayan. Hindi ko mapatunayan sa live na app (naka-hide
/// ang browser pane, kaya walang frame ang Flutter), kaya dito na lang —
/// mas mabuti rin, dahil tumatakbo ito habambuhay sa bawat `flutter test`.
void main() {
  late FakeFirebaseFirestore db;
  late ClubRepository repo;

  const qm = 'qm1';
  const iba = 'ibang-qm';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ClubRepository(
      db,
      MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: qm)),
    );
  });

  Future<void> seedClub(
    String id, {
    String ownerUid = qm,
    required DateTime createdAt,
    String? gcash,
    int members = 0,
  }) async {
    await db.collection('clubs').doc(id).set({
      'name': 'My club',
      'ownerUid': ownerUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'gcashNumber': ?gcash,
    });
    for (var i = 0; i < members; i++) {
      await db.collection('clubs').doc(id).collection('members').add({
        'name': 'Regular $i',
        'ownerUid': ownerUid,
        'skillTier': 'intermediate',
      });
    }
  }

  /// Fire-and-forget ang pagkukumpuni, kaya hindi ito tapos pagbalik ng
  /// ensureDefaultClub. Hintayin ang ilang microtask bago tingnan.
  Future<Map<String, dynamic>?> settledClub(String id) async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return (await db.collection('clubs').doc(id).get()).data();
  }

  group('bagong QM', () {
    test('gumagawa ng club kapag talagang wala pa', () async {
      final id = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect(id, isNotEmpty);
      final clubs = await db.collection('clubs').get();
      expect(clubs.docs.length, 1);
      expect(clubs.docs.first.data()['ownerUid'], qm);
    });

    test('HINDI nagdaragdag sa pangalawang tawag — ito ang orihinal na bug',
        () async {
      final first = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );
      await settledClub(first);

      final second = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect(second, first, reason: 'iisa lang dapat ang club ng QM');
      expect((await db.collection('clubs').get()).docs.length, 1);
    });
  });

  group('may club na sa server', () {
    test('ginagamit ang luma sa halip na gumawa ng bago', () async {
      await seedClub('luma', createdAt: DateTime(2026, 7, 7), members: 8);

      final id = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect(id, 'luma');
      expect((await db.collection('clubs').get()).docs.length, 1);
    });

    test('hindi kinukuha ang club ng ibang QM', () async {
      await seedClub('sa-iba', ownerUid: iba, createdAt: DateTime(2026, 7, 7));

      final id = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect(id, isNot('sa-iba'));
      final mine = await db
          .collection('clubs')
          .where('ownerUid', isEqualTo: qm)
          .get();
      expect(mine.docs.length, 1);
    });
  });

  group('ang totoong pinsala: tatlong club, hating kasaysayan', () {
    // Eksaktong hugis ng natagpuan sa Firebase noong 2026-09-06.
    setUp(() async {
      await seedClub('NK7G',
          createdAt: DateTime(2026, 9, 5, 13, 54), members: 8);
      await seedClub('mvhV',
          createdAt: DateTime(2026, 9, 6, 5, 47), gcash: '09293656299');
      await seedClub('taBQ', createdAt: DateTime(2026, 9, 6, 12, 35));
    });

    test('pinipili ang club na may walong regular', () async {
      final id = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect(id, 'NK7G', reason: 'doon ang regulars book');
    });

    test('sinasagip ang naulilang GCash number papunta sa napili', () async {
      final id = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect((await settledClub(id))!['gcashNumber'], '09293656299');
    });

    test('hindi bumubura ng kahit anong club — hindi na mababawi iyon',
        () async {
      await repo.ensureDefaultClub(ownerUid: qm, fallbackName: 'My club');
      await settledClub('NK7G');

      expect((await db.collection('clubs').get()).docs.length, 3);
    });

    test('pareho ang sagot sa bawat tawag — walang pagpapalit-palit',
        () async {
      final a = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );
      await settledClub(a);
      final b = await repo.ensureDefaultClub(
        ownerUid: qm,
        fallbackName: 'My club',
      );

      expect(b, a);
      expect((await db.collection('clubs').get()).docs.length, 3);
    });
  });
}
