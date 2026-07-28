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
  });

  final String id;
  final String name;
  final SkillTier skillTier;

  /// Puso ng fairness. Laging FieldValue.increment sa Firestore side
  /// para tama pa rin kahit offline at maraming pending writes.
  final int gamesPlayed;

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
    );
  }
}
