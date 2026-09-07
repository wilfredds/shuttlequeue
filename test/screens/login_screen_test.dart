import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/providers/auth_providers.dart';
import 'package:shuttlequeue/repositories/auth_repository.dart';
import 'package:shuttlequeue/screens/login_screen.dart';

/// Ang pinto ng app. Dito papasok ang isang totoong coach, kaya ang mga
/// tuntunin dito ay tungkol sa seguridad at sa pag-aampon ng password
/// manager — hindi lang sa hitsura.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
      : super(MockFirebaseAuth(), FakeFirebaseFirestore());

  final signInEmails = <String>[];
  final resetEmails = <String>[];
  Object? failWith;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInEmails.add(email);
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmails.add(email);
    final failure = failWith;
    if (failure != null) throw failure;
  }
}

Future<_FakeAuthRepository> _pump(WidgetTester tester) async {
  final repo = _FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _field(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );

void main() {
  testWidgets('may AutofillGroup — dito nakasalalay ang password manager',
      (tester) async {
    await _pump(tester);
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('ang password field ay current-password kapag nagsa-sign-in',
      (tester) async {
    await _pump(tester);

    final password = tester.widget<TextField>(_field('Password'));
    expect(password.autofillHints, contains(AutofillHints.password));
    expect(password.obscureText, isTrue);

    final email = tester.widget<TextField>(_field('Email'));
    expect(email.autofillHints, contains(AutofillHints.username));
    expect(email.keyboardType, TextInputType.emailAddress);
  });

  testWidgets('sa paggawa ng account, new-password naman — para mag-alok '
      'ang manager ng bagong matibay', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('New Queue Master? Create an account'));
    await tester.pumpAndSettle();

    final password = tester.widget<TextField>(_field('Password'));
    expect(password.autofillHints, contains(AutofillHints.newPassword));
  });

  testWidgets('isang password field lang — kailanman ay hindi dalawa',
      (tester) async {
    await _pump(tester);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.text('New Queue Master? Create an account'));
    await tester.pumpAndSettle();
    // Pangalan + email + password. Walang "ulitin ang password".
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('nakikita ang "nakalimutan ang password" sa sign-in',
      (tester) async {
    await _pump(tester);
    expect(find.text('Forgot your password?'), findsOneWidget);
  });

  testWidgets('ang reset ay pareho ang sagot — walang sinasabi kung may '
      'account o wala', (tester) async {
    final repo = await _pump(tester);
    repo.failWith = FirebaseAuthException(code: 'user-not-found');

    await tester.enterText(_field('Email'), 'wala@gmail.com');
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();

    // Kahit sumabog ang tawag, ganito pa rin ang mensahe.
    expect(find.textContaining('If that email has an account'), findsOneWidget);
  });

  testWidgets('nililinis ang email bago ipadala', (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(_field('Email'), '  Coach@Gmail.Com ');
    await tester.enterText(_field('Password'), 'basta-lang');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repo.signInEmails, ['coach@gmail.com']);
  });

  testWidgets('lumalabas ang lakas ng password habang nagta-type',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('New Queue Master? Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Password'), 'abc');
    await tester.pumpAndSettle();
    expect(find.text('Too short'), findsOneWidget);

    await tester.enterText(_field('Password'), 'paluinmoyanshuttle');
    await tester.pumpAndSettle();
    expect(find.text('Strong'), findsOneWidget);
  });

  testWidgets('pagkatapos ng limang maling password, hihinto muna',
      (tester) async {
    final repo = await _pump(tester);
    repo.failWith = FirebaseAuthException(code: 'invalid-credential');

    await tester.enterText(_field('Email'), 'coach@gmail.com');
    await tester.enterText(_field('Password'), 'mali-ito');

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.textContaining('Sign in'));
      await tester.pumpAndSettle();
    }

    expect(repo.signInEmails.length, 5);
    expect(find.textContaining('Try again in'), findsOneWidget);

    // Naka-lock: hindi na tumatawag kahit pindutin pa.
    await tester.tap(find.textContaining('Try again in'));
    await tester.pumpAndSettle();
    expect(repo.signInEmails.length, 5, reason: 'dapat hindi na tumawag');
  });

  testWidgets('ang walang signal ay HINDI binibilang na panghuhula',
      (tester) async {
    final repo = await _pump(tester);
    repo.failWith = FirebaseAuthException(code: 'network-request-failed');

    await tester.enterText(_field('Email'), 'coach@gmail.com');
    await tester.enterText(_field('Password'), 'tama-naman-ito');

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.textContaining('Sign in'));
      await tester.pumpAndSettle();
    }

    // Anim na subok sa gym na walang signal — bawal siyang ma-lock doon.
    expect(find.textContaining('Try again in'), findsNothing);
    expect(repo.signInEmails.length, 6);
  });

  testWidgets('sinasabi ang patakaran sa datos bago pa may maitala',
      (tester) async {
    await _pump(tester);
    expect(find.textContaining('no phone numbers'), findsOneWidget);
  });
}
