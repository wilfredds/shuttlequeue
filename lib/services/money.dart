/// Pera helpers. Isang panuntunan lang: **int centavos sa loob, piso sa UI.**
/// Walang double kahit saan sa pera — ang float rounding ang pinakamabilis
/// na paraan para magkulang ng piso ang koleksyon ng QM.
library;

/// Piso string mula sa QM (hal. "350", "350.50", "₱1,200") papuntang centavos.
/// Bumabalik ng null kapag hindi mabasa — ang caller ang magpapakita ng error.
int? parsePesosToCentavos(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;

  // Higit sa isang decimal point = hindi valid (hal. "1.2.3").
  final parts = cleaned.split('.');
  if (parts.length > 2) return null;

  final pesos = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
  if (pesos == null) return null;

  var centavos = 0;
  if (parts.length == 2 && parts[1].isNotEmpty) {
    // Kunin ang unang dalawang digit lang: "350.5" -> 50, "350.567" -> 56.
    final fraction = parts[1].padRight(2, '0').substring(0, 2);
    final parsed = int.tryParse(fraction);
    if (parsed == null) return null;
    centavos = parsed;
  }

  return pesos * 100 + centavos;
}

/// Pang-display: 35000 -> "₱350.00". Ginagamit sa fee breakdown at share text.
String formatCentavos(int centavos) {
  final negative = centavos < 0;
  final absolute = centavos.abs();
  final pesos = absolute ~/ 100;
  final remainder = absolute % 100;

  final buffer = StringBuffer();
  final digits = pesos.toString();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  final sign = negative ? '-' : '';
  return '$sign₱$buffer.${remainder.toString().padLeft(2, '0')}';
}
