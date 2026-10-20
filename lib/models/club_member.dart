/// Ang "regulars book" — tumatagal sa pagitan ng mga session.
///
/// PRIVACY (RA 10173): pangalan at skill lang. Walang phone number,
/// walang email, walang address ng manlalaro. Ang bawat dagdag na field
/// dito ay dagdag na obligasyon — mag-isip nang dalawang beses.
library;

import 'enums.dart';

class ClubMember {
  const ClubMember({
    required this.id,
    required this.name,
    required this.skillTier,
    required this.aliases,
    required this.balanceCentavos,
    required this.sessionsAttended,
    required this.createdAt,
    this.lastPlayedAt,
    this.avatarSeed,
  });

  final String id;
  final String name;

  /// Naaalalang tier — ito ang dahilan kung bakit mas mabilis ang week 2
  /// kaysa week 1: hindi na kailangang i-tag ulit ang lahat.
  final SkillTier skillTier;

  /// Mga palayaw na ginagamit sa Messenger list: "Kuya Jun", "JUN P.".
  /// Ginagamit ng smart name matching sa import.
  final List<String> aliases;

  /// Utang (positibo) o sobrang bayad (negatibo) na dala sa susunod na gabi.
  final int balanceCentavos;

  final int sessionsAttended;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;

  /// Ang mukhang pinili ng QM para sa taong ito, naaalala sa pagitan ng
  /// mga gabi. Null ang karaniwan: galing sa pangalan ang mukha.
  ///
  /// Bilang bago na ito, hindi pangalan: wala itong sinasabi tungkol sa
  /// tao na hindi pa alam ng app. Ang privacy na nakasulat sa itaas ay
  /// nananatiling totoo — pangalan at skill pa rin lang ang hawak natin.
  final int? avatarSeed;

  bool get hasOutstandingBalance => balanceCentavos != 0;

  /// Lahat ng pangalang pwedeng itugma sa isang pasted line.
  List<String> get allNames => [name, ...aliases];

  ClubMember copyWith({
    String? name,
    SkillTier? skillTier,
    List<String>? aliases,
    int? balanceCentavos,
    int? sessionsAttended,
    DateTime? lastPlayedAt,
    int? avatarSeed,
  }) {
    return ClubMember(
      id: id,
      name: name ?? this.name,
      skillTier: skillTier ?? this.skillTier,
      aliases: aliases ?? this.aliases,
      balanceCentavos: balanceCentavos ?? this.balanceCentavos,
      sessionsAttended: sessionsAttended ?? this.sessionsAttended,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }
}
