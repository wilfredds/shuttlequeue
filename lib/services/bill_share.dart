/// Ang teksto ng bayarin na ipinapadala sa group chat.
///
/// Purong Dart, walang Flutter — kaya may test ito. Nandito ito at hindi sa
/// loob ng screen dahil **ito ang tanging bahagi ng pera na nakikita ng
/// manlalaro.** Ang bill screen ay nasa telepono ng QM; ito ang pumupunta
/// sa Messenger, binabasa ng labindalawang tao, at pinagbabatayan nila kung
/// magkano ang ipapadala. Ang hindi masusubok na teksto ay hindi dapat ang
/// huling salita tungkol sa pera ng iba.
///
/// ANG PANUNTUNAN DITO: **ipaliwanag ang halaga, huwag lang ilista.** Sa
/// per-game, ang "₱160" at ang "₱60" sa magkasunod na linya ay mukhang
/// pagkakamali kung walang katabing dahilan. Ang bill na hindi maipaliwanag
/// ay hindi binabayaran nang walang tanong — at ang tanong na iyon ay
/// dumarating sa QM, labindalawang beses.
library;

import 'fee_calculator.dart';
import 'money.dart';

String buildBillShareText({
  required String title,
  required String dateLabel,
  required String venue,
  required FeeBreakdown breakdown,
  required String gcashTitle,
  String? gcashNumber,
  required String totalLabel,
  required String collectedLabel,
  required String outstandingLabel,

  /// Ibinibigay lang sa per-game: ginagawang "8 games" ang bilang.
  String Function(int games)? gamesLabel,

  /// Ibinibigay lang sa per-game: ang isang linyang nagpapaliwanag ng
  /// lahat ng halaga sa ibaba nito.
  String? basisLine,
}) {
  final buffer = StringBuffer()..writeln(title)..writeln(dateLabel);

  // Pwedeng wala pang venue kapag mabilis na ginawa ang session.
  if (venue.trim().isNotEmpty) buffer.writeln(venue);

  if (basisLine != null && basisLine.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(basisLine);
  }

  buffer.writeln();

  for (final line in breakdown.lines) {
    // Tsek para sa bayad na, gitling para sa hindi pa. Sinadya ang
    // gitling at hindi ang pulang krus: ang listahang ito ay babasahin ng
    // mismong mga tao, at ang hindi pa nagbabayad ay hindi pa, hindi mali.
    final mark = line.hasPaid ? '✅' : '—';
    final games = gamesLabel == null ? '' : ' (${gamesLabel(line.gamesPlayed)})';
    buffer.writeln(
      '$mark ${line.name}$games: ${formatCentavos(line.totalCentavos)}',
    );
  }

  if (gcashNumber != null && gcashNumber.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('$gcashTitle: $gcashNumber');
  }

  buffer
    ..writeln()
    ..writeln('$totalLabel: ${formatCentavos(breakdown.chargedTotalCentavos)}')
    ..writeln('$collectedLabel: ${formatCentavos(breakdown.collectedCentavos)}')
    ..writeln(
      '$outstandingLabel: ${formatCentavos(breakdown.outstandingCentavos)}',
    );

  return buffer.toString();
}
