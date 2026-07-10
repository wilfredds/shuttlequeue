import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/app.dart';
import 'package:shuttlequeue/providers/auth_providers.dart';

void main() {
  testWidgets('Logged-out user lands on the login screen', (tester) async {
    // Ino-override ang auth stream ng "walang naka-login" para hindi
    // kailanganin ang totoong Firebase sa test — ito ang dahilan kung
    // bakit providers ang daanan, hindi FirebaseAuth.instance nang direkta.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ],
        child: const ShuttleQueueApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ShuttleQueue'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // Sign-in mode: email + password fields lang (walang name field).
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
