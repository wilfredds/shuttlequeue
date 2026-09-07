import 'dart:math' as math;

/// Dalawang purong tuntunin na nagbabantay sa pinto ng app.
///
/// Walang Firebase dito, walang widget — kaya nasusubok sila nang tuwiran,
/// at iisa ang lugar na babaguhin kapag hinigpitan natin ang patakaran.

/// Ang pinakamaikling password para sa BAGONG account.
///
/// Anim ang minimum ng Firebase. Walo ang hinihingi natin: hindi
/// nakakaabala sa isang taong minsan lang mag-sign-up, pero malaking
/// pinagkaiba laban sa panghuhula.
///
/// TANDAAN: sa PAGGAWA lang ng account ito. Bawal ipilit sa pag-sign-in —
/// may mga account nang gawa noong anim pa ang minimum, at hindi natin
/// sila puwedeng i-lock sa labas ng sarili nilang gabi.
const kMinNewPasswordLength = 8;

enum PasswordStrength {
  /// Kulang sa haba — hindi pa ito tatanggapin.
  tooShort,

  /// Sapat ang haba, pero hulaan agad.
  weak,

  /// Ayos na para sa ganitong app.
  fair,

  /// Matibay.
  strong,
}

/// Sinusukat ang password ng bagong QM.
///
/// Sinasadyang HINDI ito nagbabawal maliban sa haba. Ang mahahabang
/// listahan ng panuntunan ("kailangan ng simbolo!") ay nagtutulak sa tao
/// na gumawa ng `Password1!` — mas mahulaan pa iyon kaysa tatlong salitang
/// pinagdikit. Haba muna, tapos gabay.
PasswordStrength ratePassword(String password) {
  if (password.length < kMinNewPasswordLength) return PasswordStrength.tooShort;

  var variety = 0;
  if (password.contains(RegExp('[a-z]'))) variety++;
  if (password.contains(RegExp('[A-Z]'))) variety++;
  if (password.contains(RegExp('[0-9]'))) variety++;
  if (password.contains(RegExp('[^A-Za-z0-9]'))) variety++;

  // Ang haba ang pinakamalakas na panangga, kaya ito ang pinakamabigat.
  if (password.length >= 16) return PasswordStrength.strong;
  if (password.length >= 12) {
    return variety >= 2 ? PasswordStrength.strong : PasswordStrength.fair;
  }
  if (variety >= 3) return PasswordStrength.fair;
  return PasswordStrength.weak;
}

/// Gaano katagal ipagpapaliban ang susunod na subok pagkatapos ng
/// sunod-sunod na palyadong sign-in.
///
/// May sariling panangga ang Firebase sa server, pero dumarating iyon
/// bilang biglaang `too-many-requests` na walang paliwanag. Ito ang
/// nauuna: dahan-dahang bumabagal, may nakikitang countdown, at
/// nagpapabagal sa panghuhula bago pa man umabot sa server.
///
/// Hindi ito seguridad na nakasalalay sa client — ang totoong hadlang ay
/// nasa Firebase at sa rules. Ito ay para maayos ang asal ng app at
/// mabawasan ang ingay.
Duration signInLockout(int consecutiveFailures) {
  const freeAttempts = 4;
  if (consecutiveFailures <= freeAttempts) return Duration.zero;

  // 15s, 30s, 60s, 120s... hanggang 5 minuto.
  final step = consecutiveFailures - freeAttempts;
  final seconds = 15 * math.pow(2, step - 1).toInt();
  return Duration(seconds: math.min(seconds, 300));
}

/// Payak na tsek ng hugis ng email.
///
/// Sinadyang maluwag. Ang mahihigpit na regex ay tumatanggi sa mga tunay
/// na address (may plus sign, may bagong TLD), at ang parusa sa pagkakamali
/// ay hindi makapasok ang QM. Ang totoong beripikasyon ay ang mismong
/// pag-sign-in.
bool looksLikeEmail(String value) {
  final trimmed = value.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(trimmed);
}

/// Nililinis ang email bago ipadala.
///
/// Ang pag-paste mula sa Messenger ay madalas may kasamang espasyo, at
/// ang malaking titik ay karaniwan sa keyboard ng telepono. Parehong
/// nagdudulot ng "walang ganyang account" na nakakalito.
String normalizeEmail(String value) => value.trim().toLowerCase();
