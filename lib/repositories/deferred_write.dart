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

/// Sinasalaan ang isang collection query sa may-ari nito.
///
/// **BAKIT KAILANGAN ITO SA BAWAT QUERY — huwag itong tanggalin.**
///
/// Ang security rules ay HINDI filter. Kapag ang rule ay nakasalalay sa
/// `resource.data.ownerUid`, kaya iyong suriin ng Firestore para sa
/// **isang** dokumento — pero para sa isang buong collection, hindi nito
/// kayang patunayan na lahat ng dokumento ay papasa, kaya tinatanggihan
/// nito ang BUONG query. Hindi ito nagsasala; nagtataboy ito.
///
/// Kaya kailangang isulat ng query mismo ang parehong kondisyon ng rule.
/// Kapag nawala ito: PERMISSION_DENIED ang listahan, at dahil stream ang
/// karamihan dito, ang nakikita ng QM ay walang katapusang spinner —
/// walang error, walang mensahe. Ganito eksakto nasira ang roster, courts,
/// matches, bill at regulars nang tanggalin natin ang get() sa rules.
Query<Map<String, dynamic>> ownedQuery(
  Query<Map<String, dynamic>> collection,
  String ownerUid,
) {
  return collection.where('ownerUid', isEqualTo: ownerUid);
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

/// Isang club na nakita habang naghahanap ng default club ng QM.
typedef ClubCandidate = ({
  String id,
  DateTime? createdAt,
  int memberCount,
  String? gcashNumber,
});

/// Ang napiling club, kasama ang isang maliit na pagkukumpuni kung kailangan.
typedef ClubChoice = ({String id, String? adoptGcash});

/// Pumipili ng ISA kapag may higit sa isang club ang QM.
///
/// Walang paraan ang Firestore para pigilan ang dalawang device (o dalawang
/// browser) na sabay gumawa habang offline: lokal ang doc ID, kaya parehong
/// tatanggapin ng server. Nangyari na ito sa totoong datos — tatlong club sa
/// iisang QM, at HATI ang kanyang kasaysayan: nasa isa ang walong regular,
/// nasa iba ang GCash number.
///
/// Kaya dalawa ang ginagawa natin:
///
/// 1. **Pumili nang deterministiko** — pinakamaraming miyembro ang panalo,
///    dahil ang regulars book ang hindi na mababawi (may tier, palayaw, at
///    balanse ang bawat isa). Kung pantay, ang mas matanda; kung pantay pa
///    rin, ang ID — para pareho ang sagot sa bawat device at hindi
///    nagpapalit-palit ang app. Ang `limit(1)` na walang orderBy ay HINDI
///    deterministiko.
///
/// 2. **Sagipin ang GCash number** kung wala ito sa napili pero nasa isang
///    naulit. Isang field lang ito, kaya ligtas ibalik — hindi tulad ng
///    pagsasanib ng buong listahan ng miyembro.
///
/// Kung MAGKAIBA ang numero sa mga naulit, hindi tayo manghuhula: iiwan
/// nating walang laman at ang QM na ang magpapasya — kapareho ng patakaran
/// ng NameMatcher na hindi kailanman nag-aautomatiko ng malabo.
ClubChoice? pickPrimaryClub(Iterable<ClubCandidate> clubs) {
  final list = clubs.toList();
  if (list.isEmpty) return null;

  list.sort((a, b) {
    // Una: sino ang may pinakamaraming regular.
    final byMembers = b.memberCount.compareTo(a.memberCount);
    if (byMembers != 0) return byMembers;

    // Pangalawa: ang mas matanda. Ang walang createdAt ay kagagawa pa lang
    // (serverTimestamp muna ay null sa lokal), kaya sa dulo iyon.
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at != null && bt != null) {
      final byAge = at.compareTo(bt);
      if (byAge != 0) return byAge;
    } else if (at == null && bt != null) {
      return 1;
    } else if (at != null && bt == null) {
      return -1;
    }

    // Panghuli: ang ID — walang kahulugan, basta pareho sa lahat.
    return a.id.compareTo(b.id);
  });

  final winner = list.first;
  if (winner.gcashNumber != null) return (id: winner.id, adoptGcash: null);

  // Walang numero ang napili. May naiwan kaya sa mga naulit?
  final orphaned = list
      .skip(1)
      .map((club) => club.gcashNumber)
      .whereType<String>()
      .toSet();

  return (
    id: winner.id,
    adoptGcash: orphaned.length == 1 ? orphaned.first : null,
  );
}
