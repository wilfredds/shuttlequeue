import 'enums.dart';

/// Isang tao sa loob ng isang gabi. Sinasadya ang pag-copy ng name at
/// skillTier mula sa ClubMember: kung palitan ng QM ang tier ngayong gabi,
/// hindi dapat magbago ang lahat ng nakaraang sessions.
class SessionPlayer {
  const SessionPlayer({
    required this.id,
    required this.name,
    required this.skillTier,
    required this.gamesPlayed,
    required this.waitingSince,
    required this.status,
    required this.shuttlesUsed,
    required this.hasPaid,
    required this.createdAt,
    this.memberId,
    this.avatarSeed,
    this.gamesAtJoin = 0,
  });

  final String id;
  final String name;
  final SkillTier skillTier;

  /// Puso ng fairness. Laging FieldValue.increment sa Firestore side
  /// para tama pa rin kahit offline at maraming pending writes.
  ///
  /// TANDAAN: hindi ito ang bilang ng larong NILARO ng tao. Ang dumating
  /// nang huli ay binubuhat sa [gamesAtJoin] pagpasok niya. Para sa pera,
  /// gamitin ang [billableGames].
  final int gamesPlayed;

  /// Ang pasimula na ibinigay sa dumating nang huli.
  ///
  /// Ang dumating nang alas-nuwebe ay hindi pwedeng magsimula sa zero: uunahin
  /// siya ng algorithm sa lahat ng naghihintay mula alas-otso. Kaya binubuhat
  /// siya sa pinakamababa sa pila (tingnan ang `addLateArrival`). Zero ito
  /// para sa lahat ng nandoon na mula sa simula.
  ///
  /// ITINATAGO ITO DAHIL SA PERA. Noong ang hatian ay per-head, walang
  /// pakialam ang bill sa bilang ng laro at kayang ilihim ang pagbuhat na
  /// ito sa loob ng `gamesPlayed`. Sa per-game, ang bawat larong hindi
  /// nilaro ay tunay na piso: binabayaran ng dumating nang huli ang tatlong
  /// larong wala siya, at ang lahat ng iba ay kulang ang bayad dahil
  /// nakatali sa isang halaga ang kabuuan.
  final int gamesAtJoin;

  /// Ang mga larong talagang nilaro ngayong gabi — ito ang sinisingil.
  ///
  /// Hindi kailanman negatibo: ang sirang undo ay dapat maging zero na
  /// singil, hindi kredito na walang pinanggalingan.
  int get billableGames {
    final played = gamesPlayed - gamesAtJoin;
    return played < 0 ? 0 : played;
  }

  /// Kailan huling bumalik sa pila — ito ang tie-breaker kapag pareho
  /// ang gamesPlayed. Client clock ito (tingnan R-10 sa design brief).
  final DateTime waitingSince;

  final PlayerStatus status;
  final int shuttlesUsed;
  final bool hasPaid;
  final DateTime createdAt;

  /// Link pabalik sa clubs/{clubId}/members/{memberId}. Null kapag
  /// bisita lang na minsan naglaro — hindi lahat ay kailangang maging regular.
  final String? memberId;

  /// Ang mukhang pinili ng QM, kung may pinili siya.
  ///
  /// Null ang karaniwan, at ang ibig sabihin ay "galing sa pangalan" —
  /// tingnan ang `services/player_character.dart`. Hindi hinuhulaan ng app
  /// ang kasarian ng kahit sino; kapag mali ang napuntang mukha, ito ang
  /// sagot ng QM. Kinokopya ito mula sa ClubMember kapag regular ang tao,
  /// kaya naaalala ito sa susunod na gabi.
  ///
  /// Sinasadya ang kopya dito at hindi lookup sa member, kapareho ng
  /// ginawa sa `name` at `skillTier`: ang pagpalit ngayong gabi ay hindi
  /// dapat bumalik at magpalit ng mukha sa recap ng nakaraang buwan.
  final int? avatarSeed;

  bool get isRegular => memberId != null;

  SessionPlayer copyWith({
    String? name,
    SkillTier? skillTier,
    int? gamesPlayed,
    DateTime? waitingSince,
    PlayerStatus? status,
    int? shuttlesUsed,
    bool? hasPaid,
    String? memberId,
    int? avatarSeed,
    int? gamesAtJoin,
  }) {
    return SessionPlayer(
      id: id,
      name: name ?? this.name,
      skillTier: skillTier ?? this.skillTier,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      waitingSince: waitingSince ?? this.waitingSince,
      status: status ?? this.status,
      shuttlesUsed: shuttlesUsed ?? this.shuttlesUsed,
      hasPaid: hasPaid ?? this.hasPaid,
      createdAt: createdAt,
      memberId: memberId ?? this.memberId,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      gamesAtJoin: gamesAtJoin ?? this.gamesAtJoin,
    );
  }
}
