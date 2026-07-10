import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/auth_gate.dart';

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
      theme: _buildTheme(),
      home: const AuthGate(),
    );
  }

  /// Theme tuned for the live-session UX requirement: the QM is standing in a
  /// bright gym, glancing at arm's length. High contrast + large tap targets.
  ThemeData _buildTheme() {
    const courtGreen = Color(0xFF1B5E20);

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: courtGreen,
        brightness: Brightness.light,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      // 56dp minimum ang mga pangunahing buttons — madaling tamaan kahit
      // nagmamadali at isang kamay lang ang libre.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(minTileHeight: 56),
    );
  }
}
