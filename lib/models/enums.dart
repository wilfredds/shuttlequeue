/// Lahat ng enum na may wire value sa Firestore. Iisang lugar lang para
/// hindi magkahiwa-hiwalay ang spelling ng mga string sa buong codebase.
///
/// Panuntunan: kapag hindi kilala ang value na galing sa Firestore, huwag
/// mag-throw — bumalik sa ligtas na default. Mas mabuting may isang maling
/// tier kaysa hindi mabuksan ang buong session ng QM sa gitna ng gabi.
library;

enum SkillTier {
  beginner('beginner'),
  intermediate('intermediate'),
  advanced('advanced');

  const SkillTier(this.value);

  final String value;

  /// Sinusukat kung gaano kalayo ang dalawang tier (0 = pareho, 2 = magkaibang dulo).
  /// Ginagamit ng MatchmakingService para sa "within one tier" na grouping.
  int distanceTo(SkillTier other) => (index - other.index).abs();

  static SkillTier fromValue(String? value) {
    return SkillTier.values.firstWhere(
      (tier) => tier.value == value,
      orElse: () => SkillTier.intermediate,
    );
  }
}

enum PlayerStatus {
  queued('queued'),
  playing('playing'),
  resting('resting'),
  left('left');

  const PlayerStatus(this.value);

  final String value;

  /// Kasama sa hatian ng bayad ang lahat maliban sa umalis nang maaga?
  /// Hindi — per spec, kahit umalis ay may share pa rin. Ang "attended"
  /// ay hawak ng FeeCalculator; dito puro queue eligibility lang.
  bool get isEligibleForMatch => this == PlayerStatus.queued;

  static PlayerStatus fromValue(String? value) {
    return PlayerStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PlayerStatus.queued,
    );
  }
}

enum SessionStatus {
  setup('setup'),
  live('live'),
  ended('ended');

  const SessionStatus(this.value);

  final String value;

  static SessionStatus fromValue(String? value) {
    return SessionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SessionStatus.setup,
    );
  }
}

enum CourtStatus {
  free('free'),
  playing('playing');

  const CourtStatus(this.value);

  final String value;

  static CourtStatus fromValue(String? value) {
    return CourtStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CourtStatus.free,
    );
  }
}

enum FeeMode {
  /// Hati ang court fee, tapos bayad mo ang sarili mong shuttles.
  perHead('per_head'),

  /// Ipunin lahat (court + shuttles) at pantay-pantay ang hati.
  american('american');

  const FeeMode(this.value);

  final String value;

  static FeeMode fromValue(String? value) {
    return FeeMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => FeeMode.perHead,
    );
  }
}
