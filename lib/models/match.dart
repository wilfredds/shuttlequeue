/// Isang laro sa isang court. Ang endedAt == null ang ibig sabihin ay
/// kasalukuyang naglalaro pa.
///
/// Ang score ay optional sa v1 — hindi natin pipilitin ang QM na mag-encode
/// ng puntos ng bawat laro. Pero ini-imbak natin ang teams at oras para
/// sa night recap cards at future skill rating (tingnan ang design brief).
class GameMatch {
  const GameMatch({
    required this.id,
    required this.courtId,
    required this.teamA,
    required this.teamB,
    required this.startedAt,
    this.scoreA,
    this.scoreB,
    this.endedAt,
  });

  final String id;
  final String courtId;

  /// Player IDs — dalawa bawat team (doubles ang default sa social badminton).
  final List<String> teamA;
  final List<String> teamB;

  final int? scoreA;
  final int? scoreB;
  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isInProgress => endedAt == null;

  /// Lahat ng naglaro — ginagamit sa "no-repeat rotation" para malaman
  /// kung sino na ang nagkasama o nagkalaban ngayong gabi.
  List<String> get allPlayerIds => [...teamA, ...teamB];

  Duration? get duration => endedAt?.difference(startedAt);
}
