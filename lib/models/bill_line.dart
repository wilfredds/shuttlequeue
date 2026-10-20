/// Isang naka-freeze na linya ng bayarin.
///
/// Kapag sinimulan na ng QM ang pangongolekta, **hindi na dapat gumalaw ang
/// mga halaga** (R-09). Kung may dumating na late at muling nag-compute ang
/// buong bill, ang limang taong nagbayad na ng ₱300 ay sobra na pala — at
/// ang QM ang mag-aabono ng diperensya.
///
/// Kaya sa pag-finalize, isinusulat natin ang mga halaga bilang datos.
/// Ang `hasPaid` ay nananatili sa player doc: patuloy pa rin ang koleksyon,
/// ang presyo lang ang hindi na nagbabago.
library;

class BillLine {
  const BillLine({
    required this.playerId,
    required this.name,
    required this.courtShareCentavos,
    required this.shuttleShareCentavos,
    this.gamesPlayed = 0,
  });

  final String playerId;
  final String name;
  final int courtShareCentavos;
  final int shuttleShareCentavos;

  /// Ilang laro ang pinagbatayan ng halagang ito.
  ///
  /// Sa `perGame`, ito ang buong paliwanag ng bill: hindi sapat ang
  /// "₱160" kapag ang katabi ay may "₱60". Naka-freeze ito kasama ng
  /// halaga — kung sa player doc natin ito kukunin, magbabago ang bilang
  /// pagkatapos ng lock samantalang ang singil ay hindi, at iyon ang
  /// eksaktong hindi pagkakatugma na iniiwasan ng lock.
  ///
  /// Zero ang default dahil ang mga lumang bill doc na nasa Firestore na
  /// ay wala pa nito.
  final int gamesPlayed;

  int get totalCentavos => courtShareCentavos + shuttleShareCentavos;
}
