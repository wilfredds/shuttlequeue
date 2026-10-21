import '../models/enums.dart';
import '../models/session.dart';

/// Ang listahan ng gabi, hinati ayon sa tanong na dala ng QM sa app.
///
/// Isang tanong lang ang nasa isip niya pagbukas: **may laro ba ngayon?**
/// Kaya isa lang ang session na itinataas — ang natitira ay konteksto.
class GroupedSessions {
  const GroupedSessions({
    required this.tonight,
    required this.upcoming,
    required this.earlier,
  });

  /// Ang gabing nangyayari na o mangyayari ngayong araw. Ito ang hero.
  final Session? tonight;

  /// Mga darating pa, pinakamalapit muna.
  final List<Session> upcoming;

  /// Mga tapos na, pinakabago muna.
  final List<Session> earlier;

  bool get isEmpty => tonight == null && upcoming.isEmpty && earlier.isEmpty;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Hinahati ang mga gabi para sa dashboard.
///
/// Ang tuntunin sa "tonight", sunod-sunod:
///   1. Kung may LIVE, iyon — may tumatakbong laro, wala nang mas mahalaga
///      kaysa doon, kahit lumagpas na ng hatinggabi ang gabi.
///   2. Kung wala, ang gabi ngayong araw — kahit tapos na, dahil ang bayad
///      ay karaniwang kinokolekta pagkatapos.
///   3. Kung marami sa iisang araw, ang pinakamaaga.
GroupedSessions groupSessions(List<Session> sessions, DateTime now) {
  final live = <Session>[];
  final today = <Session>[];
  final upcoming = <Session>[];
  final earlier = <Session>[];

  // Kahapon pa rin ang bilang, para sa gabing lumagpas ng hatinggabi.
  final yesterday = now.subtract(const Duration(days: 1));

  for (final session in sessions) {
    // ANG DAGDAG NA TANONG DITO AY "KAILAN?", AT MAY PINAGMULAN ITO.
    //
    // Dati, ang kahit anong `live` ay nananalo sa hero, kahit kailan pa ang
    // petsa nito. Mukhang tama — pero walang paraan noon para tapusin ang
    // isang session, kaya ang isang pagsubok noong isang linggo ay nanatiling
    // live magpakailanman at inagaw nito ang puwesto ng "tonight" araw-araw
    // mula noon. Ang tunay na gabi ngayon ay naitulak pababa sa listahan.
    //
    // Mayroon nang "End session" ngayon, pero hindi iyon sapat: makakalimutan
    // ito, at hindi dapat permanenteng masira ang dashboard ng isang
    // nakalimutang pindot. Ang live na mas matanda pa sa kahapon ay itinuturing
    // nang lipas — babalik ito sa pagkakasunod-sunod ayon sa petsa, kung saan
    // nararapat.
    final isRecent = _sameDay(session.sessionDate, now) ||
        _sameDay(session.sessionDate, yesterday);

    if (session.status == SessionStatus.live && isRecent) {
      live.add(session);
    } else if (_sameDay(session.sessionDate, now)) {
      today.add(session);
    } else if (session.sessionDate.isAfter(now)) {
      upcoming.add(session);
    } else {
      earlier.add(session);
    }
  }

  live.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
  today.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

  final Session? tonight =
      live.isNotEmpty ? live.first : (today.isNotEmpty ? today.first : null);

  // Ang natitira sa live/today ay hindi nawawala — pumapasok sila sa
  // upcoming, dahil hindi natin puwedeng itago ang isang gabi kahit
  // isa lang ang kasya sa hero.
  for (final rest in [...live, ...today]) {
    if (identical(rest, tonight)) continue;
    upcoming.add(rest);
  }

  upcoming.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
  earlier.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

  return GroupedSessions(
    tonight: tonight,
    upcoming: upcoming,
    earlier: earlier,
  );
}
