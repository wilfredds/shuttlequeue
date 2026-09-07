import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/models/bill_line.dart';
import 'package:shuttlequeue/models/club.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/models/synced.dart';
import 'package:shuttlequeue/providers/firebase_providers.dart';
import 'package:shuttlequeue/providers/session_providers.dart';
import 'package:shuttlequeue/screens/cost_split_screen.dart';

/// R-09 — naipadala pero hindi ko pa nakitang tumakbo.
///
/// Ang panganib na binabantayan nito ay totoo at nangyayari: nagsimula nang
/// mangolekta ang QM, tapos may dumating pang isa. Kung gagalaw ang presyo
/// pagkatapos may nagbayad na, may pagtatalo sa gym — at ang QM ang
/// magbabayad ng diperensya.
final _date = DateTime(2026, 9, 5, 20);

Session _session({DateTime? finalizedAt}) => Session(
      id: 's1',
      ownerUid: 'qm',
      clubId: 'c1',
      title: 'Salamat sa Laro',
      venue: 'Yspacio, Alapan, Imus',
      sessionDate: _date,
      status: SessionStatus.live,
      courtCount: 2,
      courtFeeCentavos: 120000, // ₱1,200
      shuttlePriceCentavos: 10000,
      feeMode: FeeMode.perHead,
      createdAt: _date,
      updatedAt: _date,
      billFinalizedAt: finalizedAt,
    );

SessionPlayer _player(String name) => SessionPlayer(
      id: 'id-$name',
      name: name,
      skillTier: SkillTier.intermediate,
      gamesPlayed: 1,
      waitingSince: _date,
      status: PlayerStatus.queued,
      shuttlesUsed: 0,
      hasPaid: false,
      createdAt: _date,
    );

/// Ang apat na naunang dumating, naka-lock sa ₱300 bawat isa.
List<BillLine> _frozenFour() => [
      for (final name in ['Ana', 'Ben', 'Carlo', 'Dina'])
        BillLine(
          playerId: 'id-$name',
          name: name,
          courtShareCentavos: 30000,
          shuttleShareCentavos: 0,
        ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required Session session,
  required List<String> roster,
  List<BillLine> frozen = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Ang _FeeTile ay umaabot sa repository (may mga tap na sumusulat),
        // kaya kailangan ng pekeng Firebase — kung hindi, "No Firebase App".
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        firebaseAuthProvider.overrideWithValue(
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'qm')),
        ),
        sessionProvider('s1').overrideWith((ref) => Stream.value(session)),
        playersProvider('s1').overrideWith(
          (ref) => Stream.value(
            Synced.settled(roster.map(_player).toList()),
          ),
        ),
        billProvider('s1').overrideWith((ref) => Stream.value(frozen)),
        clubProvider.overrideWith((ref) => Stream<Club?>.value(null)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CostSplitScreen(sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bago mag-lock: hinahati ng buhay na kuwenta sa apat',
      (tester) async {
    await _pump(
      tester,
      session: _session(),
      roster: ['Ana', 'Ben', 'Carlo', 'Dina'],
    );

    // ₱1,200 / 4 = ₱300
    expect(find.textContaining('300.00'), findsWidgets);
  });

  testWidgets('bago mag-lock: ang dumating na panlima AY nakakabago ng presyo',
      (tester) async {
    await _pump(
      tester,
      session: _session(),
      roster: ['Ana', 'Ben', 'Carlo', 'Dina', 'Emman'],
    );

    // ₱1,200 / 5 = ₱240 — tama ito habang hindi pa nangongolekta.
    expect(find.textContaining('240.00'), findsWidgets);
    expect(find.textContaining('300.00'), findsNothing);
  });

  testWidgets('R-09 ANG MAHALAGA: naka-lock na, hindi na gumagalaw ang presyo '
      'kahit may dumating pa', (tester) async {
    await _pump(
      tester,
      session: _session(finalizedAt: _date.add(const Duration(hours: 3))),
      roster: ['Ana', 'Ben', 'Carlo', 'Dina', 'Emman'],
      frozen: _frozenFour(),
    );

    // Nanatiling ₱300 ang apat na naunang nagbayad...
    expect(find.textContaining('300.00'), findsWidgets);
    // ...at HINDI ito naging ₱240. Ito ang buong punto ng R-09.
    expect(
      find.textContaining('240.00'),
      findsNothing,
      reason: 'gumalaw ang presyo pagkatapos mangolekta — bawal',
    );
  });

  testWidgets('naka-lock: sinasabi kung kailan pa naka-lock', (tester) async {
    await _pump(
      tester,
      session: _session(finalizedAt: _date.add(const Duration(hours: 3))),
      roster: ['Ana', 'Ben', 'Carlo', 'Dina'],
      frozen: _frozenFour(),
    );

    // Kailangang malinaw sa QM na naka-lock — kung hindi, magtataka siya
    // kung bakit hindi gumagalaw ang numero.
    expect(find.textContaining('11:00 PM'), findsOneWidget);
  });

  testWidgets('walang manlalaro: may paliwanag, hindi blangko', (tester) async {
    await _pump(tester, session: _session(), roster: const []);

    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Text), findsWidgets);
  });
}
