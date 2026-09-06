/// Ang club ng Queue Master.
///
/// PRIVACY: ang `gcashNumber` ay numero ng QM mismo — ang taong
/// nangongolekta — hindi ng mga manlalaro. Sinasadyang hindi ito
/// naka-hardcode sa source: bawat QM ay may sariling numero, kaya kapag
/// ang coach na ang gumamit ng app, sa KANYA dapat mapunta ang bayad,
/// hindi sa nagtayo ng app.
library;

class Club {
  const Club({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.gcashNumber,
  });

  final String id;
  final String name;
  final String ownerUid;

  /// 11 digits, nagsisimula sa 09. Null kapag hindi pa naitatakda.
  final String? gcashNumber;

  bool get hasGcash => (gcashNumber ?? '').isNotEmpty;

  /// "09293656299" -> "0929 365 6299" — mas madaling basahin at i-type
  /// ng manlalaro sa GCash app niya.
  String get formattedGcash {
    final digits = (gcashNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return gcashNumber ?? '';
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} '
        '${digits.substring(7)}';
  }
}

/// Tinatanggap lang ang totoong hugis ng PH mobile number.
/// Bumabalik ng nalinis na digits, o null kapag hindi valid.
String? normalizeGcashNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('09')) return digits;
  // Tinatanggap din ang +63 917... na anyo.
  if (digits.length == 12 && digits.startsWith('639')) {
    return '0${digits.substring(2)}';
  }
  return null;
}
