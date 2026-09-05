/// Kailan ang susunod na gabi.
///
/// Ang club ay tumatakbo nang lingguhan — patunay mismo ang schedule nila
/// sa Reclub: Thursday, Friday, Sunday, Monday, paulit-ulit. Kapag
/// inuulit ng QM ang isang session, halos palaging ang susunod na
/// katulad na araw ang ibig niyang sabihin.
library;

/// Ang susunod na paglitaw ng araw ng linggo ng [source], simula ngayon.
///
/// Kung ang [now] ay nasa parehong araw ng linggo, ngayon na iyon —
/// kadalasan ay ino-organisa ng QM ang gabi mismong araw na iyon,
/// minsan pagkatapos na ng nakatakdang oras. Hindi natin siya itutulak
/// sa susunod na linggo dahil lang 30 minutong huli siya.
///
/// Ang oras ay kinukuha mula sa [source]; ang petsa lang ang gumagalaw.
/// Palagi pa rin itong nababago ng QM sa date picker — mungkahi lang ito.
DateTime nextOccurrence(DateTime source, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  // Ilang araw pasulong bago tumama sa parehong araw ng linggo?
  // DateTime.weekday: 1 = Lunes ... 7 = Linggo.
  final daysAhead = (source.weekday - today.weekday + 7) % 7;

  final target = today.add(Duration(days: daysAhead));

  return DateTime(
    target.year,
    target.month,
    target.day,
    source.hour,
    source.minute,
  );
}
