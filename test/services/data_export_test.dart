import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/bill_line.dart';
import 'package:shuttlequeue/models/club.dart';
import 'package:shuttlequeue/models/club_member.dart';
import 'package:shuttlequeue/models/court.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/services/data_export.dart';

/// Ang file na ito ang TANGING kopya ng datos ng QM sa labas ng Firestore —
/// walang naka-iskedyul na backup sa libreng tier. Kaya ang tinitingnan
/// dito ay hindi kung "gumagana", kundi kung **kumpleto**: kung mabubura
/// bukas ang lahat, maibabalik ba ang gabi mula rito?
final _date = DateTime.utc(2026, 9, 5, 12);

Club _club() => const Club(
      id: 'club1',
      name: 'SmashMate',
      ownerUid: 'qm',
      gcashNumber: '09293656299',
    );

ClubMember _member(String name, {int balance = 0}) => ClubMember(
      id: 'm-$name',
      name: name,
      skillTier: SkillTier.advanced,
      aliases: ['Kuya $name'],
      sessionsAttended: 7,
      balanceCentavos: balance,
      createdAt: _date,
      lastPlayedAt: _date,
    );

SessionExport _night(String id, DateTime date) => SessionExport(
      session: Session(
        id: id,
        ownerUid: 'qm',
        clubId: 'club1',
        title: id,
        venue: 'Yspacio',
        sessionDate: date,
        status: SessionStatus.ended,
        courtCount: 2,
        courtFeeCentavos: 120000,
        shuttlePriceCentavos: 10000,
        feeMode: FeeMode.perHead,
        createdAt: date,
        updatedAt: date,
      ),
      players: [
        SessionPlayer(
          id: 'p1',
          name: 'Ana',
          skillTier: SkillTier.intermediate,
          gamesPlayed: 3,
          waitingSince: date,
          status: PlayerStatus.queued,
          shuttlesUsed: 1,
          hasPaid: true,
          createdAt: date,
          memberId: 'm-Ana',
        ),
      ],
      courts: const [
        Court(id: 'c1', label: 'Court 1', status: CourtStatus.free),
      ],
      matches: [
        GameMatch(
          id: 'g1',
          courtId: 'c1',
          teamA: const ['p1', 'p2'],
          teamB: const ['p3', 'p4'],
          startedAt: date,
          endedAt: date.add(const Duration(minutes: 15)),
        ),
      ],
      bill: const [
        BillLine(
          playerId: 'p1',
          name: 'Ana',
          courtShareCentavos: 30000,
          shuttleShareCentavos: 2500,
        ),
      ],
    );

Map<String, dynamic> _export({
  Club? club,
  List<ClubMember> members = const [],
  List<SessionExport> sessions = const [],
}) =>
    buildDataExport(
      club: club,
      members: members,
      sessions: sessions,
      exportedAt: _date,
      appVersion: '1.0.0',
    );

void main() {
  group('ang file ay nagpapakilala ng sarili', () {
    test('may format version, app version at petsa', () {
      final head = _export()['shuttlequeue'] as Map<String, dynamic>;

      expect(head['formatVersion'], kExportFormatVersion);
      expect(head['appVersion'], '1.0.0');
      expect(head['exportedAt'], '2026-09-05T12:00:00.000Z');
    });
  });

  group('kumpleto ang laman — ito ang buong punto', () {
    test('nasa loob ang regulars book kasama ang balanse at palayaw', () {
      final export = _export(members: [_member('Ana', balance: 13334)]);
      final m = (export['members'] as List).single as Map<String, dynamic>;

      expect(m['id'], 'm-Ana');
      expect(m['name'], 'Ana');
      expect(m['skillTier'], 'advanced');
      expect(m['aliases'], ['Kuya Ana']);
      expect(m['sessionsAttended'], 7);
      // Ang dalang utang ang pinakamahirap mabawi kapag nawala — buwan
      // ng pagtitipon ang nakasalalay dito.
      expect(m['balanceCentavos'], 13334);
    });

    test('bawat gabi ay may kasamang players, courts, matches at bill', () {
      final export = _export(sessions: [_night('Lunes', _date)]);
      final s = (export['sessions'] as List).single as Map<String, dynamic>;

      expect(s['title'], 'Lunes');
      expect(s['courtFeeCentavos'], 120000);
      expect(s['feeMode'], 'per_head');
      expect((s['players'] as List).length, 1);
      expect((s['courts'] as List).length, 1);
      expect((s['matches'] as List).length, 1);
      expect((s['bill'] as List).length, 1);
    });

    test('nananatili ang mga ID kaya naibabalik ang ugnayan', () {
      // Kung walang ID, ang laban ay listahan lang ng estranghero.
      final export = _export(
        members: [_member('Ana')],
        sessions: [_night('Lunes', _date)],
      );
      final s = (export['sessions'] as List).single as Map<String, dynamic>;
      final player = (s['players'] as List).single as Map<String, dynamic>;
      final match = (s['matches'] as List).single as Map<String, dynamic>;

      expect(player['id'], 'p1');
      expect(player['memberId'], 'm-Ana', reason: 'tali sa regulars book');
      expect(match['teamA'], contains('p1'));
      expect(match['courtId'], 'c1');
    });

    test('kasama ang GCash number ng club', () {
      final export = _export(club: _club());
      expect(
        (export['club'] as Map)['gcashNumber'],
        '09293656299',
      );
    });

    test('walang club pa: hindi bumabagsak', () {
      final export = _export();
      expect(export['club'], isNull);
      expect(export['members'], isEmpty);
      expect(export['sessions'], isEmpty);
    });
  });

  group('privacy — RA 10173', () {
    test('walang email, telepono o uid sa laman ng file', () {
      final export = _export(
        club: _club(),
        members: [_member('Ana', balance: 500)],
        sessions: [_night('Lunes', _date)],
      );

      // Tinatanggal muna ang header. May paalala roon na nakasulat mismo
      // ang salitang "phone" ("no phone numbers"), at ang hinahanap natin
      // ay DATOS ng manlalaro — hindi ang pangungusap tungkol dito.
      // (Nahuli ako ng sarili kong test dito.)
      final payload = Map<String, dynamic>.from(export)..remove('shuttlequeue');
      final json = encodeDataExport(payload).toLowerCase();

      // Ang GCash ay numero ng QM MISMO at sinadyang nandoon.
      expect(json.contains('@'), isFalse, reason: 'walang email');
      expect(json.contains('email'), isFalse);
      expect(json.contains('phone'), isFalse);
      expect(json.contains('password'), isFalse);
      expect(json.contains('owneruid'), isFalse,
          reason: 'walang saysay sa tao ang uid, at paulit-ulit lang');
    });

    test('may paalala sa header kung ano ang nasa loob', () {
      final head = _export()['shuttlequeue'] as Map<String, dynamic>;
      expect(head['note'], contains('no phone numbers'));
    });
  });

  group('nabubuksan ng ibang programa', () {
    test('tunay na JSON ang lumalabas', () {
      final text = encodeDataExport(
        _export(club: _club(), members: [_member('Niña')]),
      );

      final reparsed = jsonDecode(text) as Map<String, dynamic>;
      expect(
        ((reparsed['members'] as List).single as Map)['name'],
        'Niña',
        reason: 'buhay pa ang ñ pagkatapos ng ikot',
      );
    });

    test('may indent — babasahin ito ng tao sa masamang gabi', () {
      expect(encodeDataExport(_export()), contains('\n  '));
    });
  });

  group('pangalan ng file at buod', () {
    test('nakaayos ayon sa petsa kapag marami nang backup', () {
      expect(
        exportFileName(DateTime(2026, 9, 7)),
        'shuttlequeue-2026-09-07.json',
      );
      // Zero-padded, kaya tama ang pagkakasunod-sunod sa folder.
      expect(
        exportFileName(DateTime(2026, 12, 25)),
        'shuttlequeue-2026-12-25.json',
      );
    });

    test('ang buod ay nagbibilang ng totoong nakuha', () {
      final export = _export(
        members: [_member('Ana'), _member('Ben')],
        sessions: [_night('Lunes', _date), _night('Huwebes', _date)],
      );

      expect(exportSummary(export), '2 sessions · 2 player rows · 2 regulars');
    });
  });
}
