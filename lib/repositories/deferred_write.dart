/// Kung paano tayo sumusulat sa Firestore habang offline.
///
/// ANG PINAKAMAHALAGANG BAGAY NA DAPAT MAINTINDIHAN SA BUONG APP:
///
/// Ang `Future` na ibinabalik ng isang Firestore write ay **hindi
/// natatapos hangga't hindi ito na-acknowledge ng server.** Naka-apply na
/// agad ang datos sa local cache — makikita mo na ito sa screen — pero
/// ang Future mismo ay nakabitin.
///
/// Ibig sabihin, ang `await batch.commit()` sa gitna ng isang UI flow ay
/// **nagha-hang nang tuluyan kapag walang signal.** Sa court ng Yspacio,
/// ang "Next match" ay iikot na lang nang iikot at hindi bubukas.
///
/// Kaya walang UI path na naghihintay ng commit. Sinusulat natin, agad
/// tayong bumabalik, at kung tanggihan ito ng server, sinasabi natin sa QM
/// (tingnan ang sync_error_provider.dart). Ang tahimik na pagkabigo ang
/// pinakamasama sa lahat — iyon ang dahilan kung bakit napakahirap
/// hanapin ng bug na "naglalaho ang bagong session".
library;

import 'package:cloud_firestore/cloud_firestore.dart';

typedef WriteErrorReporter = void Function(Object error);

/// Para sa mga read na kailangan bago magpatuloy (hal. "may club na ba
/// tayo?" bago gumawa ng session).
///
/// Ang default ng Firestore ay `Source.serverAndCache`: sinusubukan muna
/// ang server, at "fumafall back sa cache kung hindi maabot ang server" —
/// pero walang garantiya sa dokumentasyon kung gaano katagal bago
/// mapagdesisyunan iyon. Dalawang beses na tayong nadamay sa ganitong
/// klaseng kalabuan sa offline behavior ng Firestore (tingnan ang git
/// history — ang batch na `get()` sa rules, at ang naka-await na sulat).
/// Sinasadyang cache-only na lang ito: agad-agad, walang pag-asa sa
/// network — at dahil single-device pa rin ang v1 (R-02), ang lokal na
/// cache mismo ang tanging katotohanang mahalaga.
const cacheOnly = GetOptions(source: Source.cache);

/// Isinusulat nang hindi hinihintay ang server. Ang anumang pagkabigo ay
/// iniuulat, hindi nilulunok.
void fireAndForget(Future<void> write, WriteErrorReporter? onError) {
  write.catchError((Object error) {
    onError?.call(error);
  });
}

/// "Court 2" bago ang "Court 10".
///
/// Ang plain string sort ay naglalagay ng "Court 10" bago ang "Court 2",
/// kaya kapag binawasan ang bilang ng court, maling court ang nabubura.
int naturalCompare(String a, String b) {
  final numA = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
  final numB = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
  if (numA != null && numB != null) return numA.compareTo(numB);
  return a.compareTo(b);
}
