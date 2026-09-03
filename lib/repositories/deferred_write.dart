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

typedef WriteErrorReporter = void Function(Object error);

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
