import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/services/session_grouping.dart';

final _now = DateTime(2026, 9, 7, 19, 0); // Lunes ng gabi, papunta pa lang

Session _s(
  String id,
  DateTime date, {
  SessionStatus status = SessionStatus.setup,
}) =>
    Session(
      id: id,
      ownerUid: 'qm',
      clubId: 'c1',
      title: id,
      venue: 'Yspacio',
      sessionDate: date,
      status: status,
      courtCount: 2,
      courtFeeCentavos: 120000,
      shuttlePriceCentavos: 10000,
      feeMode: FeeMode.perHead,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  test('walang gabi: walang itinataas', () {
    final g = groupSessions(const [], _now);
    expect(g.tonight, isNull);
    expect(g.isEmpty, isTrue);
  });

  test('ang gabi ngayong araw ang itinataas', () {
    final g = groupSessions([
      _s('bukas', DateTime(2026, 9, 8, 20)),
      _s('ngayon', DateTime(2026, 9, 7, 20)),
      _s('noon', DateTime(2026, 8, 31, 20)),
    ], _now);

    expect(g.tonight?.id, 'ngayon');
    expect(g.upcoming.map((s) => s.id), ['bukas']);
    expect(g.earlier.map((s) => s.id), ['noon']);
  });

  test('ang LIVE ang nananaig kahit ibang araw ang petsa nito', () {
    // Lumagpas na ng hatinggabi ang gabi. Tumatakbo pa rin ang laro,
    // kaya wala nang mas mahalaga kaysa doon.
    final g = groupSessions([
      _s('ngayon', DateTime(2026, 9, 7, 21)),
      _s('kahapon-tuloy', DateTime(2026, 9, 6, 20), status: SessionStatus.live),
    ], _now);

    expect(g.tonight?.id, 'kahapon-tuloy');
  });

  test('ang nakalimutang live noong isang linggo ay hindi na nananaig', () {
    // ITO ANG GALING SA TOTOONG PAGSUBOK: walang paraan noon para tapusin
    // ang session, kaya nanatiling live ang isang lumang pagsubok at inagaw
    // nito ang hero araw-araw mula noon. Ang tunay na gabi ngayon ay
    // naitulak pababa, at mukhang sira ang dashboard.
    final g = groupSessions([
      _s('ngayon', DateTime(2026, 9, 7, 21)),
      _s('lumang-test', DateTime(2026, 8, 31, 20), status: SessionStatus.live),
    ], _now);

    expect(g.tonight?.id, 'ngayon');
    // Hindi ito nawawala — nasa nakaraan lang ito, kung saan nararapat.
    expect(g.earlier.map((s) => s.id), contains('lumang-test'));
  });

  test('ang gabing tapos na ngayong araw ay itinataas pa rin', () {
    // Karaniwang pagkatapos ng laro kinokolekta ang bayad — kailangan
    // pa rin niyang mabilis itong mabuksan.
    final g = groupSessions([
      _s('tapos', DateTime(2026, 9, 7, 8), status: SessionStatus.ended),
    ], _now);

    expect(g.tonight?.id, 'tapos');
  });

  test('kapag dalawa sa iisang araw, ang mas maaga ang hero — '
      'at hindi nawawala ang isa', () {
    final g = groupSessions([
      _s('gabi', DateTime(2026, 9, 7, 20)),
      _s('umaga', DateTime(2026, 9, 7, 8)),
    ], _now);

    expect(g.tonight?.id, 'umaga');
    expect(g.upcoming.map((s) => s.id), ['gabi'],
        reason: 'walang gabing basta nawawala');
  });

  test('ang darating ay pinakamalapit muna; ang nakaraan ay pinakabago muna',
      () {
    final g = groupSessions([
      _s('a', DateTime(2026, 9, 20, 20)),
      _s('b', DateTime(2026, 9, 10, 20)),
      _s('c', DateTime(2026, 8, 1, 20)),
      _s('d', DateTime(2026, 8, 25, 20)),
    ], _now);

    expect(g.upcoming.map((s) => s.id), ['b', 'a']);
    expect(g.earlier.map((s) => s.id), ['d', 'c']);
  });

  test('nabibilang ang bawat gabi nang eksaktong isang beses', () {
    final all = [
      _s('a', DateTime(2026, 9, 20, 20)),
      _s('b', DateTime(2026, 9, 7, 20)),
      _s('c', DateTime(2026, 8, 1, 20)),
      _s('d', DateTime(2026, 9, 5, 20), status: SessionStatus.live),
      _s('e', DateTime(2026, 9, 7, 6)),
    ];
    final g = groupSessions(all, _now);

    final seen = [
      if (g.tonight != null) g.tonight!.id,
      ...g.upcoming.map((s) => s.id),
      ...g.earlier.map((s) => s.id),
    ];
    expect(seen..sort(), ['a', 'b', 'c', 'd', 'e']);
  });
}
