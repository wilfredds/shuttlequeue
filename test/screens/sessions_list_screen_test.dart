import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/models/club_member.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/synced.dart';
import 'package:shuttlequeue/providers/auth_providers.dart';
import 'package:shuttlequeue/providers/firebase_providers.dart';
import 'package:shuttlequeue/providers/session_providers.dart';
import 'package:shuttlequeue/screens/sessions_list_screen.dart';

/// Ang unang screen na nakikita ng QM. Isang tanong lang ang dala niya:
/// **may laro ba ngayon?** — kaya iyon ang sinusukat dito.
Session _s(
  String id,
  DateTime date, {
  SessionStatus status = SessionStatus.setup,
  String venue = 'Yspacio',
}) =>
    Session(
      id: id,
      ownerUid: 'qm',
      clubId: 'c1',
      title: id,
      venue: venue,
      sessionDate: date,
      status: status,
      courtCount: 2,
      courtFeeCentavos: 120000,
      shuttlePriceCentavos: 10000,
      feeMode: FeeMode.perHead,
      createdAt: date,
      updatedAt: date,
    );

ClubMember _member(String name, {int balance = 0}) => ClubMember(
      id: 'id-$name',
      name: name,
      skillTier: SkillTier.intermediate,
      aliases: const [],
      sessionsAttended: 1,
      balanceCentavos: balance,
      createdAt: DateTime(2026, 7, 7),
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Session> sessions = const [],
  List<ClubMember> members = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'qm')),
        ),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(
            MockUser(uid: 'qm', displayName: 'France'),
          ),
        ),
        sessionsProvider.overrideWith(
          (ref) => Stream.value(Synced.settled(sessions)),
        ),
        clubMembersProvider.overrideWith((ref) => Stream.value(members)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // BITAG: ang tumitibok na tuldok ng LIVE ay walang katapusang
        // animation, kaya HINDI KAILANMAN natatapos ang pumpAndSettle
        // kapag may live na gabi sa screen. Pinapatay natin ang animation
        // dito — at bonus, ito rin ang daanang sinusunod kapag naka-reduce
        // motion ang tao, kaya nasusubok din iyon.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const SessionsListScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('walang gabi pa: isang malinaw na paanyaya, hindi blangko',
      (tester) async {
    await _pump(tester);

    expect(find.textContaining('No sessions'), findsWidgets);
    // Dalawa: ang nasa gitna at ang FAB. Pareho silang nagbubukas ng form.
    expect(find.text('New session'), findsWidgets);
  });

  testWidgets('ipinapakita ang pangalan ng QM sa banda', (tester) async {
    await _pump(tester);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets('ang gabing tumatakbo ay itinataas na may Resume',
      (tester) async {
    await _pump(
      tester,
      sessions: [
        _s('Lunes Palo', DateTime.now(), status: SessionStatus.live),
        _s('Sa isang linggo',
            DateTime.now().add(const Duration(days: 7))),
      ],
    );

    expect(find.text('Resume the night'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
  });

  testWidgets('ang gabi ngayong araw na hindi pa nagsisimula ay "Open"',
      (tester) async {
    // Alas-8 ng gabi ngayong araw, wala pang laro: dapat handa pa rin
    // itong buksan sa isang tap.
    final today = DateTime.now();
    await _pump(
      tester,
      sessions: [
        _s('Ngayong gabi',
            DateTime(today.year, today.month, today.day, 20)),
      ],
    );

    expect(find.text('Open tonight'), findsOneWidget);
    expect(find.text('Tonight'), findsOneWidget);
  });

  testWidgets('kapag walang gabi ngayong araw, walang hero — '
      'hindi tayo nagpapanggap', (tester) async {
    await _pump(
      tester,
      sessions: [_s('Noong isang linggo',
          DateTime.now().subtract(const Duration(days: 7)))],
    );

    expect(find.text('Open tonight'), findsNothing);
    expect(find.text('Resume the night'), findsNothing);
    expect(find.text('EARLIER'), findsOneWidget);
  });

  testWidgets('ipinapakita ng banda ang bilang ng regular at ang dalang utang',
      (tester) async {
    await _pump(
      tester,
      members: [
        _member('Ana', balance: 13334),   // ₱133.34 na utang
        _member('Ben', balance: 6666),    // ₱66.66
        _member('Carlo'),                 // walang utang
        _member('Dina', balance: -5000),  // sobra ang bayad — hindi utang
      ],
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Regulars'), findsOneWidget);
    // 133.34 + 66.66 = 200.00. Ang sobrang bayad ni Dina ay HINDI ibinabawas:
    // ang tanong ay "magkano ang dapat kong singilin", hindi ang neto.
    expect(find.text('₱200.00'), findsOneWidget);
  });

  testWidgets('ang sign out ay nagtatanong muna — walang signal, '
      'walang balikan', (tester) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.textContaining('needs internet'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('ang export ay nasa menu — ito ang tanging backup sa '
      'libreng tier', (tester) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Export all my data'), findsOneWidget);
  });
}
