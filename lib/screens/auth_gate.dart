import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'login_screen.dart';
import 'sessions_placeholder_screen.dart';

/// Ang tanging daanan papasok ng app: naka-login → sessions,
/// hindi → login. Walang ibang ruta papunta sa session screens,
/// kaya imposibleng maabot ng logged-out user ang mga iyon.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user == null
          ? const LoginScreen()
          : const SessionsPlaceholderScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Bihira ito (hal. sirang plugin init) — ipakita na lang ang login
      // kaysa mag-crash; makakapag-try ulit ang QM mula roon.
      error: (_, _) => const LoginScreen(),
    );
  }
}
