/// Hatian ng bayad sa dulo ng gabi.
///
/// Puro Dart, walang Firestore — kaya masusubok nang eksakto. Lahat ng
/// halaga ay **int centavos**; walang double kahit saan.
///
/// ANG PINAKAMAHALAGANG PANUNTUNAN: ang kabuuan ng lahat ng share ay dapat
/// **eksaktong katumbas** ng kabuuang gastos. Kulang o sobra ng isang
/// centavo, ang QM ang magbabayad ng diperensya mula sa sarili niyang bulsa.
library;

import '../models/enums.dart';
import '../models/session_player.dart';

class FeeLine {
  const FeeLine({
    required this.playerId,
    required this.name,
    required this.courtShareCentavos,
    required this.shuttleShareCentavos,
    required this.gamesPlayed,
    required this.hasPaid,
    required this.hasLeft,
  });

  final String playerId;
  final String name;
  final int courtShareCentavos;
  final int shuttleShareCentavos;

  /// Ilang laro ang sinisingil sa hilerang ito. Sa `perGame` ito ang
  /// batayan ng court share; sa iba, pang-konteksto lang — pero kailangan
  /// pa rin ito ng bill screen para maipakita kung bakit ganoon ang halaga.
  final int gamesPlayed;

  final bool hasPaid;
  final bool hasLeft;

  int get totalCentavos => courtShareCentavos + shuttleShareCentavos;
}

class FeeBreakdown {
  const FeeBreakdown({
    required this.lines,
    required this.mode,
    required this.expectedTotalCentavos,
    this.courtFeeCentavos = 0,
    this.totalPlayerGames = 0,
  });

  final List<FeeLine> lines;
  final FeeMode mode;

  /// Ang totoong gastos ng gabi: court fee + lahat ng shuttle.
  final int expectedTotalCentavos;

  /// Ang renta ng court lang, bukod sa shuttle.
  final int courtFeeCentavos;

  /// Suma ng `gamesPlayed` ng lahat ng dumalo. Sa doubles, apat na
  /// player-game ang isang laro — kaya ito ang bilang ng upuan sa court
  /// na binayaran ngayong gabi, hindi ang bilang ng laro.
  final int totalPlayerGames;

  /// **Pang-display lang.** Humigit-kumulang kung magkano ang isang laro
  /// kada tao, para may masabi ang QM kapag tinanong. Ang tunay na singil
  /// ay nasa bawat [FeeLine]; dito may tinatapyas na centavo ang paghahati.
  int get courtRatePerGameCentavos =>
      totalPlayerGames == 0 ? 0 : courtFeeCentavos ~/ totalPlayerGames;

  int get chargedTotalCentavos =>
      lines.fold(0, (sum, line) => sum + line.totalCentavos);

  int get collectedCentavos => lines
      .where((line) => line.hasPaid)
      .fold(0, (sum, line) => sum + line.totalCentavos);

  int get outstandingCentavos => chargedTotalCentavos - collectedCentavos;

  int get paidCount => lines.where((line) => line.hasPaid).length;

  /// Dapat laging true. Nasa test ito bilang property — kung mabasag,
  /// may mali sa paghahati ng tira.
  bool get balances => chargedTotalCentavos == expectedTotalCentavos;
}

class FeeCalculator {
  const FeeCalculator();

  /// ASSUMPTION (spec §5 vs §6): ang umalis nang maaga ay **kasama pa rin**
  /// sa hatian. Naglaro na sila; kabahagi sila ng renta ng court. Sinasabi
  /// ng §5 na "retained for the fee split", kaya iyon ang sinusunod dito.
  /// Kung ayaw ng QM, pwede niyang tanggalin ang tao sa roster.
  FeeBreakdown calculate({
    required List<SessionPlayer> players,
    required int courtFeeCentavos,
    required int shuttlePriceCentavos,
    required FeeMode feeMode,
    bool includeLeavers = true,
  }) {
    final attendees = players
        .where((p) => includeLeavers || p.status != PlayerStatus.left)
        .toList();

    // Nakaayos ayon sa pangalan para **matatag** ang pagkakabigay ng tira:
    // pareho ang resulta tuwing kinakalkula, kaya hindi nagbabago ang
    // singil sa isang tao sa bawat pag-refresh ng screen.
    attendees.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });

    final totalShuttles =
        attendees.fold(0, (sum, p) => sum + p.shuttlesUsed);
    final shuttleCost = totalShuttles * shuttlePriceCentavos;
    final expectedTotal = courtFeeCentavos + shuttleCost;
    // billableGames, HINDI gamesPlayed. Ang dumating nang huli ay binubuhat
    // sa pinakamababa sa pila para patas ang pagkakasunod — at ang pagbuhat
    // na iyon ay hindi laro na nilaro niya. Tingnan ang SessionPlayer.
    final totalPlayerGames =
        attendees.fold(0, (sum, p) => sum + p.billableGames);

    // Walang dumalo: walang hahatiin. Nagbabalik ng walang laman kaysa
    // mag-divide by zero at pumatay sa screen.
    if (attendees.isEmpty) {
      return FeeBreakdown(
        lines: const [],
        mode: feeMode,
        expectedTotalCentavos: 0,
      );
    }

    final lines = <FeeLine>[];

    switch (feeMode) {
      case FeeMode.perHead:
        final courtShares = _split(courtFeeCentavos, attendees.length);
        for (var i = 0; i < attendees.length; i++) {
          final player = attendees[i];
          lines.add(
            FeeLine(
              playerId: player.id,
              name: player.name,
              courtShareCentavos: courtShares[i],
              shuttleShareCentavos: player.shuttlesUsed * shuttlePriceCentavos,
              gamesPlayed: player.billableGames,
              hasPaid: player.hasPaid,
              hasLeft: player.status == PlayerStatus.left,
            ),
          );
        }

      case FeeMode.perGame:
        // ANG HINAHANAP NG QM: lumalaki ang bayad habang dumadami ang laro.
        //
        // Isang halaga pa rin ang renta ng court — hindi ito bagong presyo
        // kada laro. Hinahati natin ang renta ayon sa bilang ng laro, kaya
        // ang naglaro ng walo ay doble ang bayad sa naglaro ng apat, at ang
        // kabuuan ay napupunta pa rin nang eksakto sa renta. Ang bersyon na
        // may takdang presyo kada laro ay nanganganib na magkulang sa renta,
        // at ang QM ang aabono.
        final courtShares = _splitByWeight(
          courtFeeCentavos,
          [for (final p in attendees) p.billableGames],
        );
        for (var i = 0; i < attendees.length; i++) {
          final player = attendees[i];
          lines.add(
            FeeLine(
              playerId: player.id,
              name: player.name,
              courtShareCentavos: courtShares[i],
              shuttleShareCentavos: player.shuttlesUsed * shuttlePriceCentavos,
              gamesPlayed: player.billableGames,
              hasPaid: player.hasPaid,
              hasLeft: player.status == PlayerStatus.left,
            ),
          );
        }

      case FeeMode.american:
        // Isang bunton: court + lahat ng shuttle, tapos pantay-pantay.
        final shares = _split(expectedTotal, attendees.length);
        for (var i = 0; i < attendees.length; i++) {
          final player = attendees[i];
          lines.add(
            FeeLine(
              playerId: player.id,
              name: player.name,
              courtShareCentavos: shares[i],
              shuttleShareCentavos: 0,
              gamesPlayed: player.billableGames,
              hasPaid: player.hasPaid,
              hasLeft: player.status == PlayerStatus.left,
            ),
          );
        }
    }

    return FeeBreakdown(
      lines: lines,
      mode: feeMode,
      expectedTotalCentavos: expectedTotal,
      courtFeeCentavos: courtFeeCentavos,
      totalPlayerGames: totalPlayerGames,
    );
  }

  /// Hinahati ang [total] sa [count] na bahagi na **eksaktong nagsusuma**
  /// pabalik sa total.
  ///
  /// Ang tira ay ibinibigay isa-isa sa mga nauuna. Halimbawa: ₱1000 sa 7 tao
  /// ay 100000 ÷ 7 = 14285 na may tirang 5 — kaya limang tao ang magbabayad
  /// ng ₱142.86 at dalawa ng ₱142.85. Suma: eksaktong ₱1000.
  List<int> _split(int total, int count) {
    if (count <= 0) return const [];
    final base = total ~/ count;
    final remainder = total % count;
    return [
      for (var i = 0; i < count; i++) base + (i < remainder ? 1 : 0),
    ];
  }

  /// Hinahati ang [total] ayon sa [weights] — at **eksaktong nagsusuma**
  /// pa rin pabalik sa total.
  ///
  /// Dalawang panuntunan ang mahalaga dito:
  ///
  ///  * **Ang walang timbang ay walang bayad.** Ang tira ay ipinapamigay
  ///    lang sa may timbang. Kung hindi, ang hindi nakalaro ay masisingil
  ///    ng isang centavo para sa court — maliit na halaga, pero mali ang
  ///    sinasabi nito, at iyon ang unang pupulot ng mata sa bill.
  ///  * **Kapag walang timbang ang lahat, pantay-pantay.** Nangyayari ito
  ///    bago ang unang laro: may renta na ang court pero wala pang laro.
  ///    Kung ayon sa laro ang hatian, zero ang lahat at ang QM ang aabono
  ///    ng buong renta.
  List<int> _splitByWeight(int total, List<int> weights) {
    if (weights.isEmpty) return const [];

    final totalWeight = weights.fold(0, (sum, w) => sum + w);
    if (totalWeight <= 0) return _split(total, weights.length);

    final shares = [for (final w in weights) total * w ~/ totalWeight];

    // Ang bawat paghati ay tumatapyas ng kulang sa isang centavo, kaya ang
    // tira ay laging mas maliit sa bilang ng may timbang — hindi tayo
    // mauuwi sa loop na may natitira pa.
    var remainder = total - shares.fold(0, (sum, v) => sum + v);
    for (var i = 0; i < shares.length && remainder > 0; i++) {
      if (weights[i] <= 0) continue;
      shares[i] += 1;
      remainder--;
    }

    return shares;
  }
}
