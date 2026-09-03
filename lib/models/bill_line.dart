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
  });

  final String playerId;
  final String name;
  final int courtShareCentavos;
  final int shuttleShareCentavos;

  int get totalCentavos => courtShareCentavos + shuttleShareCentavos;
}
