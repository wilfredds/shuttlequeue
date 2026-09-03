import 'enums.dart';

/// Isang gabi ng laro. Puro Dart lang ito — walang Firestore imports —
/// para magamit sa unit tests ng FeeCalculator nang walang Firebase.
///
/// Pera: laging int centavos. Bawal ang double sa pera; ang float rounding
/// ang pinakamabilis na paraan para magkamali ng piso sa hatian.
class Session {
  const Session({
    required this.id,
    required this.ownerUid,
    required this.clubId,
    required this.title,
    required this.venue,
    required this.sessionDate,
    required this.status,
    required this.courtCount,
    required this.courtFeeCentavos,
    required this.shuttlePriceCentavos,
    required this.feeMode,
    required this.createdAt,
    required this.updatedAt,
    this.billFinalizedAt,
  });

  final String id;
  final String ownerUid;

  /// Nagli-link sa clubs/{clubId} para sa regulars book. Nullable-safe:
  /// kung walang club (hal. one-off session), empty string lang ito.
  final String clubId;

  final String title;
  final String venue;
  final DateTime sessionDate;
  final SessionStatus status;
  final int courtCount;
  final int courtFeeCentavos;
  final int shuttlePriceCentavos;
  final FeeMode feeMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Kailan ni-freeze ang bayarin. Kapag hindi null, ang mga naka-imbak na
  /// halaga sa sessions/{id}/bill ang totoo — hindi na ang live na kuwenta.
  final DateTime? billFinalizedAt;

  bool get isBillFinalized => billFinalizedAt != null;

  Session copyWith({
    String? title,
    String? venue,
    DateTime? sessionDate,
    SessionStatus? status,
    int? courtCount,
    int? courtFeeCentavos,
    int? shuttlePriceCentavos,
    FeeMode? feeMode,
    DateTime? updatedAt,
    DateTime? billFinalizedAt,
  }) {
    return Session(
      id: id,
      ownerUid: ownerUid,
      clubId: clubId,
      title: title ?? this.title,
      venue: venue ?? this.venue,
      sessionDate: sessionDate ?? this.sessionDate,
      status: status ?? this.status,
      courtCount: courtCount ?? this.courtCount,
      courtFeeCentavos: courtFeeCentavos ?? this.courtFeeCentavos,
      shuttlePriceCentavos: shuttlePriceCentavos ?? this.shuttlePriceCentavos,
      feeMode: feeMode ?? this.feeMode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billFinalizedAt: billFinalizedAt ?? this.billFinalizedAt,
    );
  }
}
