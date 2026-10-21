/// Ang pagtatapos ng gabi, nasa isang lugar.
///
/// Nandito ito at hindi sa loob ng isang screen dahil **dalawa ang pasukan**,
/// at sinasadya iyon. Ang unang bersyon ay may iisang pasukan — ang "Lock the
/// amounts" sa Money tab — at hindi ito nahanap ng totoong QM na sumubok ng
/// app. Ang nawawalang pindutan ay hindi lang abala: ang session na hindi
/// natapos ay nananatiling `live` magpakailanman, lumalaki nang walang hanggan
/// ang oras ng paghihintay ng lahat, at inaagaw nito ang puwesto ng "tonight"
/// sa dashboard araw-araw pagkatapos.
///
/// Kaya: nasa app bar (ang nakasanayang lugar) AT nasa dulo ng Recap (kung
/// saan talaga siya nakaupo kapag tapos na ang gabi). Iisang daan lang ang
/// kodigo, kaya hindi maaaring magkaiba ang bantay sa dalawang pasukan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/court.dart';
import '../providers/session_providers.dart';

/// Tinatapos ang gabi, may kumpirmasyon, at may bantay.
///
/// SINASADYANG HINAHARANGAN at hindi awtomatikong tinatapos ang laro.
/// Ang pagtatapos ng laro ay nagdaragdag ng isa sa bilang ng apat na tao,
/// at sa per-game ay pera iyon. Ang pindutang "tapusin ang gabi" ay hindi
/// dapat tahimik na nagbabago ng singil ng kahit sino — mas mabuting
/// sabihin kung aling court, at hayaan siyang pindutin ang End match doon.
Future<void> confirmEndSession(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  // Ang court doc mismo ang may hawak ng status nito. Ang dating bersyon ay
  // nagtanong sa liveMatchesProvider gamit ang `read`, at ang provider na
  // iyon ay nagbabalik ng walang laman habang hindi pa dumarating ang stream
  // niya — kaya tahimik na pumapayag ang bantay kapag hindi pa nabubuksan
  // ang Courts tab. Iyon mismo ang sitwasyong dapat nitong harangin.
  final courts =
      ref.read(courtsProvider(sessionId)).value?.data ?? const <Court>[];
  final busy = courts.where((c) => !c.isFree).toList();

  if (busy.isNotEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.endSessionBlocked(busy.map((c) => c.label).join(', ')),
          ),
        ),
      );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.endSessionConfirmTitle),
      content: Text(l10n.endSessionConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.endSessionCta),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(sessionRepositoryProvider).endSession(sessionId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.sessionEnded)));
}

/// Binubuksan muli ang gabi. Walang kumpirmasyon — walang nasisira nito,
/// at ang mali ay naibabalik sa isang pindot.
Future<void> resumeSession(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(sessionRepositoryProvider).resumeSession(sessionId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.sessionResumed)));
}
