import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/models/bill_line.dart';
import 'package:shuttlequeue/models/club.dart';
import 'package:shuttlequeue/models/club_member.dart';
import 'package:shuttlequeue/models/court.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/models/synced.dart';
import 'package:shuttlequeue/providers/auth_providers.dart';
import 'package:shuttlequeue/providers/firebase_providers.dart';
import 'package:shuttlequeue/providers/session_providers.dart';
import 'package:shuttlequeue/screens/session_detail_screen.dart';
import 'package:shuttlequeue/screens/sessions_list_screen.dart';
import 'package:shuttlequeue/theme.dart';

/// Gumagawa ng mga screenshot para sa pag-anunsyo ng app.
///
///     flutter test tool/screenshots/generate_test.dart --update-goldens
///
/// Nasa `tool/` ito at hindi sa `test/` nang sinasadya: hindi ito
/// tumatakbo sa `flutter test` at hindi ito sumisira ng CI. Ang golden ay
/// nagbabago kapag nagbago ang font o ang platform, at hindi iyon dapat
/// magpabagsak ng build.
///
/// Bakit sa test iginuguhit at hindi kinukuhanan ng litrato ang totoong
/// app? Kontrolado ang datos. Walang "test 1" na pangalan, walang lumang
/// gabi sa listahan, walang notification bar ng ibang tao — at kayang
/// ulitin ang parehong larawan bukas.
const _sessionId = 's1';

// Alas-otso ng gabi ngayong araw: ganito nakikita ng QM ang hero card.
final _today = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
  20,
);

/// Kinukuha ang mga font ng app mula sa asset bundle, at ang MaterialIcons
/// mula sa SDK. Kung wala ito, kahon-kahon ang teksto sa golden — walang
/// saysay iyon bilang screenshot.
///
/// Mahalaga na ang TOTOONG font ang nakukuha dito: ang larawang ipo-post sa
/// Facebook ay dapat kaparehong-kapareho ng makikita ng QM sa telepono
/// niya. Noong Roboto pa ang ginagamit dito, ang screenshot ay isang
/// magandang kasinungalingan.
Future<void> _loadFonts() async {
  Future<void> loadAssets(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final path in assets) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  await loadAssets('Inter', const [
    'assets/fonts/Inter-400.ttf',
    'assets/fonts/Inter-500.ttf',
    'assets/fonts/Inter-600.ttf',
  ]);
  await loadAssets('Archivo', const [
    'assets/fonts/Archivo-600.ttf',
    'assets/fonts/Archivo-800.ttf',
  ]);

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('Walang FLUTTER_ROOT — patakbuhin sa `flutter test`.');
  }
  final iconFile = File(
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      iconFile.readAsBytes().then(
            (bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
          ),
    );
  await icons.load();
}

Session _session({
  SessionStatus status = SessionStatus.live,
  String title = 'Huwebes Night Palo',
  DateTime? date,
}) => Session(
  id: _sessionId,
  ownerUid: 'qm',
  clubId: 'c1',
  title: title,
  venue: 'Yspacio Alapan, Imus',
  sessionDate: date ?? _today,
  status: status,
  courtCount: 3,
  courtFeeCentavos: 135000, // ₱1,350
  shuttlePriceCentavos: 12000, // ₱120 kada bola
  feeMode: FeeMode.perHead,
  createdAt: _today,
  updatedAt: _today,
);

SessionPlayer _p(
  String name, {
  int games = 0,
  PlayerStatus status = PlayerStatus.queued,
  SkillTier tier = SkillTier.intermediate,
  int shuttles = 0,
  bool paid = false,
  int waitMinutes = 0,
}) => SessionPlayer(
  id: 'id-$name',
  name: name,
  skillTier: tier,
  gamesPlayed: games,
  waitingSince: DateTime.now().subtract(Duration(minutes: waitMinutes)),
  status: status,
  shuttlesUsed: shuttles,
  hasPaid: paid,
  createdAt: _today,
);

/// Isang tunay na hitsura ng gabi: labindalawa, may naglalaro, may
/// naghihintay, magkakaibang bilang ng laro.
final _roster = <SessionPlayer>[
  _p('Mark', games: 3, status: PlayerStatus.playing, shuttles: 1, paid: true),
  _p('Ana', games: 3, status: PlayerStatus.playing, tier: SkillTier.advanced),
  _p('Kuya Jun', games: 3, status: PlayerStatus.playing, paid: true),
  _p('Niña', games: 3, status: PlayerStatus.playing, tier: SkillTier.beginner),
  _p('Rica', games: 2, status: PlayerStatus.playing, waitMinutes: 4),
  _p('Paolo', games: 2, status: PlayerStatus.playing, shuttles: 1),
  _p('Kim', games: 2, status: PlayerStatus.playing, tier: SkillTier.advanced),
  _p('JR', games: 2, status: PlayerStatus.playing),
  _p('Aldrin', games: 2, waitMinutes: 12, paid: true),
  _p('Bea', games: 2, waitMinutes: 14, tier: SkillTier.beginner),
  _p('Carlo', games: 1, waitMinutes: 19),
  _p('Dina', games: 1, waitMinutes: 23, tier: SkillTier.advanced),
];

final _courts = <Court>[
  const Court(
    id: 'c1',
    label: 'Court 1',
    status: CourtStatus.playing,
    currentMatchId: 'g1',
  ),
  const Court(
    id: 'c2',
    label: 'Court 2',
    status: CourtStatus.playing,
    currentMatchId: 'g2',
  ),
  const Court(id: 'c3', label: 'Court 3', status: CourtStatus.free),
];

final _matches = <GameMatch>[
  GameMatch(
    id: 'g1',
    courtId: 'c1',
    teamA: const ['id-Mark', 'id-Ana'],
    teamB: const ['id-Kuya Jun', 'id-Niña'],
    startedAt: _today.subtract(const Duration(minutes: 7)),
  ),
  GameMatch(
    id: 'g2',
    courtId: 'c2',
    teamA: const ['id-Rica', 'id-Paolo'],
    teamB: const ['id-Kim', 'id-JR'],
    startedAt: _today.subtract(const Duration(minutes: 3)),
  ),
  // Mga tapos na laro — dito nanggagaling ang laman ng Recap.
  for (final (i, teams) in <(List<String>, List<String>)>[
    (['id-Mark', 'id-Rica'], ['id-Aldrin', 'id-Bea']),
    (['id-Ana', 'id-Kim'], ['id-Carlo', 'id-Dina']),
    (['id-Kuya Jun', 'id-JR'], ['id-Mark', 'id-Paolo']),
    (['id-Niña', 'id-Aldrin'], ['id-Ana', 'id-Bea']),
    (['id-Kim', 'id-Carlo'], ['id-Rica', 'id-Kuya Jun']),
  ].indexed)
    GameMatch(
      id: 'done-$i',
      courtId: 'c1',
      teamA: teams.$1,
      teamB: teams.$2,
      startedAt: _today.subtract(Duration(minutes: 100 - i * 18)),
      endedAt: _today.subtract(Duration(minutes: 86 - i * 18)),
    ),
];

/// ₱1,350 court + 2 bola x ₱120 = ₱1,590 hinati sa labindalawa.
final _bill = <BillLine>[
  for (final p in _roster)
    BillLine(
      playerId: p.id,
      name: p.name,
      courtShareCentavos: 11250,
      shuttleShareCentavos: 2000,
    ),
];

final _members = <ClubMember>[
  for (final name in [
    'Mark',
    'Ana',
    'Kuya Jun',
    'Niña',
    'Rica',
    'Paolo',
    'Kim',
    'JR',
    'Aldrin',
    'Bea',
    'Carlo',
    'Dina',
    'Jomar',
    'Tin',
    'Alex',
    'Ryan',
    'Mae',
    'Dan',
  ])
    ClubMember(
      id: 'm-$name',
      name: name,
      skillTier: SkillTier.intermediate,
      aliases: const [],
      sessionsAttended: 6,
      balanceCentavos: name == 'Carlo' ? 13250 : 0,
      createdAt: _today,
    ),
];

Future<void> _shoot(
  WidgetTester tester,
  String file,
  Widget screen, {
  List<Session>? sessions,
  String? openTab,
}) async {
  // Naka-off ang anino sa test at iginuguhit bilang matigas na itim na
  // balangkas — mukhang sirang app iyon sa larawan. Dito ito binubuksan
  // at SIGURADONG naibabalik: tumatakbo ang assert ng Flutter sa dulo ng
  // test body pa lang, hindi pa sa tearDown.
  debugDisableShadows = false;
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'qm')),
          ),
          authStateChangesProvider.overrideWith(
            (ref) => Stream<User?>.value(
              MockUser(uid: 'qm', displayName: 'Coach France'),
            ),
          ),
          sessionsProvider.overrideWith(
            (ref) => Stream.value(Synced.settled(sessions ?? [_session()])),
          ),
          sessionProvider(
            _sessionId,
          ).overrideWith((ref) => Stream.value(_session())),
          playersProvider(
            _sessionId,
          ).overrideWith((ref) => Stream.value(Synced.settled(_roster))),
          courtsProvider(
            _sessionId,
          ).overrideWith((ref) => Stream.value(Synced.settled(_courts))),
          matchesProvider(
            _sessionId,
          ).overrideWith((ref) => Stream.value(_matches)),
          billProvider(_sessionId).overrideWith((ref) => Stream.value(_bill)),
          clubMembersProvider.overrideWith((ref) => Stream.value(_members)),
          clubProvider.overrideWith(
            (ref) => Stream.value(
              const Club(
                id: 'c1',
                name: 'SmashMate',
                ownerUid: 'qm',
                gcashNumber: '09293656299',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildShuttleQueueTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: screen,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (openTab != null) {
      await tester.tap(find.text(openTab).first);
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../marketing/$file'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // Laki ng karaniwang telepono, sa tunay na resolusyon — para malinaw
    // pa rin kapag na-upload sa Facebook.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('1 — dashboard', (tester) async {
    await _shoot(
      tester,
      '1-dashboard.png',
      const SessionsListScreen(),
      sessions: [
        _session(),
        _session(
          title: 'Lunes Palo',
          status: SessionStatus.ended,
          date: _today.subtract(const Duration(days: 3)),
        ),
        _session(
          title: 'Huwebes Night Palo',
          status: SessionStatus.ended,
          date: _today.subtract(const Duration(days: 7)),
        ),
      ],
    );
  });

  // Ang natitira ay kinukunan sa loob ng SessionDetailScreen, kaya kasama
  // ang app bar at ang apat na tab — iyon ang tunay na hitsura ng app.
  for (final (file, tab) in const [
    ('2-roster.png', 'Roster'),
    ('3-courts.png', 'Courts'),
    ('4-money.png', 'Money'),
    ('5-recap.png', 'Recap'),
  ]) {
    testWidgets(file, (tester) async {
      await _shoot(
        tester,
        file,
        const SessionDetailScreen(sessionId: _sessionId),
        openTab: tab,
      );
    });
  }
}
