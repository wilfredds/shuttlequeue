import 'enums.dart';

class Court {
  const Court({
    required this.id,
    required this.label,
    required this.status,
    this.currentMatchId,
  });

  final String id;

  /// "Court 1", "Court 2" — pwedeng palitan ng QM kung ibang tawag
  /// sa venue (hal. "Left", "Right", o numero ng gym).
  final String label;

  final CourtStatus status;
  final String? currentMatchId;

  bool get isFree => status == CourtStatus.free;

  Court copyWith({
    String? label,
    CourtStatus? status,
    String? currentMatchId,
    bool clearMatch = false,
  }) {
    return Court(
      id: id,
      label: label ?? this.label,
      status: status ?? this.status,
      currentMatchId: clearMatch ? null : (currentMatchId ?? this.currentMatchId),
    );
  }
}
