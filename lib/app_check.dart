import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check — pinapatunayan na galing sa TOTOONG app ang request.
///
/// **Ang problemang sinasagot nito.** Ang API key sa `firebase_options.dart`
/// ay hindi lihim: nakikita ito ng kahit sino sa deployed na web app. Ang
/// pumipigil sa isang estranghero na basahin ang datos ng ibang QM ay ang
/// security rules. Pero WALANG pumipigil sa kanya na paulit-ulit tumawag at
/// ubusin ang libreng kota — at kapag naubos iyon, tumitigil ang app para sa
/// LAHAT, kasama ang coach sa gitna ng gabi. Doon pumapasok ang App Check.
///
/// ## Basahin bago i-enforce
///
/// Ang App Check ay may dalawang mode sa console. Sa **monitoring** ay
/// tinitingnan lang nito kung sino ang pumapasa; walang hinaharangan. Sa
/// **enforced** ay tinatanggihan na ang hindi nakapasa.
///
/// Ang pagpindot ng Enforce nang maaga ay nagba-block ng sarili mong app —
/// kabilang ang telepono ng coach, habang may labindalawang naghihintay sa
/// court. Ang tamang pagkakasunod ay:
///
///   1. Irehistro ang web app sa reCAPTCHA v3 (libre) sa Firebase Console.
///   2. I-deploy ito na may site key. Manatili sa MONITORING.
///   3. Tingnan ang metrics sa loob ng ilang araw. Hintaying maging halos
///      lahat ay "verified" ang tunay mong trapiko.
///   4. Saka lang i-enforce.
///
/// ## Tungkol sa Android
///
/// Ang Play Integrity ay nangangailangan na galing sa Google Play ang app.
/// Ang APK natin ay naka-sideload at debug-signed, kaya HINDI ito papasa —
/// kaya debug provider ang ginagamit dito. Habang naka-monitoring, wala
/// itong epekto. Bago i-enforce ang Firestore, kailangan munang irehistro
/// ang debug token ng teleponong iyon sa console, kung hindi ay maiiwan sa
/// labas ang coach.
///
/// ## Bakit hindi ito kayang magpabagsak ng app
///
/// Nakabalot sa try/catch at hindi hinihintay ang resulta. Kung mabigo ang
/// attestation — walang signal, blocked ang reCAPTCHA, anuman — magpapatuloy
/// pa rin ang app. Ang App Check ay panangga laban sa pang-aabuso; hindi ito
/// dapat maging bagong paraan para masira ang gabi.

/// Ang reCAPTCHA v3 site key, ibinibigay sa build:
///
///     flutter build web --release \
///       --dart-define=RECAPTCHA_SITE_KEY=6Lxxxxxxxxxxxxxxxxxx
///
/// May DEFAULT ito nang sinasadya. Ang unang bersyon ay walang laman kapag
/// walang --dart-define, at iyon ay bitag: ang isang nakalimutang flag ay
/// TAHIMIK na magpapatay ng App Check, at walang magsasabi. Sa seguridad,
/// ang tahimik na pagkabukas ay mas masama kaysa sa isang repo na nakatali
/// sa isang proyekto.
///
/// Ligtas itong nasa source: pampubliko ang site key — nakikita ito sa loob
/// ng bawat page na naglo-load ng reCAPTCHA. Ang SECRET key ang hindi dapat
/// makita kahit saan maliban sa Firebase Console.
///
/// Kapag walang laman (dahil sadyang pinawalang-bisa ng --dart-define=""),
/// nilalaktawan ang buong App Check.
const kRecaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '6LeniLItAAAAADN3610w5WAIbssBTstWKiX80vxW',
);

/// BITAG NG BUILD CACHE: kapag binago ang anumang --dart-define (kasama ang
/// pag-alis nito), HINDI ito napapansin ng incremental build ng Flutter.
/// Nananatili ang lumang halaga at tahimik na naiiwang patay ang App Check —
/// naranasan ko ito: nawala ang buong sangay ng reCAPTCHA sa bundle at walang
/// anumang babala. Patakbuhin ang `flutter clean` bago mag-build kapag
/// gumalaw ang mga define. Ang tseke: dapat lumitaw ang "recaptcha" sa
/// `build/web/main.dart.js`.
///
/// Sinisimulan ang App Check kung nakaayos ito. Hindi kailanman nagta-throw.
Future<void> activateAppCheck() async {
  if (kIsWeb && kRecaptchaSiteKey.isEmpty) {
    // Wala pang site key: walang gagawin. Sinasadya ito — mas mabuti nang
    // walang App Check kaysa sa App Check na hindi kayang mag-attest.
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kRecaptchaSiteKey.isEmpty
          ? null
          : ReCaptchaV3Provider(kRecaptchaSiteKey),
      // Tingnan ang tala tungkol sa Android sa itaas: hindi papasa ang
      // naka-sideload na APK sa Play Integrity.
      providerAndroid: const AndroidDebugProvider(),
    );
  } catch (error, stack) {
    // Sinasadyang nilulunok. Walang gagawin ang QM tungkol dito sa gitna
    // ng gabi, at ang app ay dapat magpatuloy.
    debugPrint('App Check hindi nasimulan: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
  }
}
