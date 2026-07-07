import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// M0 placeholder — proves the scaffold + Firebase wiring works end to end.
/// Papalitan ito ng auth gate sa M1.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Defensive: sa widget tests walang Firebase.initializeApp, kaya huwag
    // mag-assume na may naka-init na app.
    final firebaseStatus = Firebase.apps.isNotEmpty
        ? l10n.m0FirebaseConnected(Firebase.app().options.projectId)
        : l10n.m0FirebaseNotInitialized;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_tennis,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(l10n.appTitle, style: theme.textTheme.displaySmall),
              const SizedBox(height: 32),
              _CheckRow(label: l10n.m0ScaffoldReady),
              _CheckRow(label: firebaseStatus, ok: Firebase.apps.isNotEmpty),
              _CheckRow(label: l10n.m0OfflinePersistence),
              const SizedBox(height: 32),
              Text(
                l10n.m0NextMilestone,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, this.ok = true});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? theme.colorScheme.primary : theme.colorScheme.error,
            size: 22,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
