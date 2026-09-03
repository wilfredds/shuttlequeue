import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ang huling pagkabigo ng isang sulat na hindi hinintay ng UI.
///
/// BAKIT KAILANGAN ITO: may mga sulat na sinasadyang hindi ino-await para
/// hindi ma-block ang QM habang offline. Ang panganib ng ganoon ay
/// **tahimik na pagkabigo** — kapag tinanggihan ito ng security rules,
/// ibinabalik ng Firestore ang local cache at basta na lang nawawala ang
/// datos sa screen, nang walang anumang paliwanag.
///
/// Nangyari ito nang totoo: naglalaho ang bagong session pagkapindot ng
/// Create dahil tinatanggihan ng rules ang batch. Walang error, walang
/// mensahe — kaya imposibleng ma-diagnose mula sa app. Mula ngayon,
/// may sinasabi ito.
class SyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void report(Object error) => state = error.toString();

  void clear() => state = null;
}

final syncErrorProvider =
    NotifierProvider<SyncErrorNotifier, String?>(SyncErrorNotifier.new);
