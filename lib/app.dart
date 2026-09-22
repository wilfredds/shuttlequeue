import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/sync_error_provider.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';

/// Root widget. Walang Firebase init dito — nasa main.dart yun — para
/// pwedeng i-pump ang buong app sa widget tests nang walang network.
class ShuttleQueueApp extends StatelessWidget {
  const ShuttleQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildShuttleQueueTheme(),
      home: const _SyncErrorListener(child: AuthGate()),
    );
  }
}

/// Ipinapakita ang mga sulat na tinanggihan ng server.
///
/// Ang ilang sulat ay sinasadyang hindi hinihintay para hindi ma-block ang
/// QM habang offline. Kung mabigo ang mga iyon, dati ay tahimik lang silang
/// nawawala — kaya nga hindi malaman kung bakit biglang naglalaho ang bagong
/// session. Ngayon, may sinasabi.
class _SyncErrorListener extends ConsumerWidget {
  const _SyncErrorListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(syncErrorProvider, (previous, next) {
      if (next == null) return;
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.syncFailed),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.syncFailedDismiss,
            onPressed: () => ref.read(syncErrorProvider.notifier).clear(),
          ),
        ),
      );
    });

    return child;
  }
}
