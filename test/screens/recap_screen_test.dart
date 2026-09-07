import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/l10n/app_localizations.dart';
import 'package:shuttlequeue/models/enums.dart';
import 'package:shuttlequeue/models/match.dart';
import 'package:shuttlequeue/models/session.dart';
import 'package:shuttlequeue/models/session_player.dart';
import 'package:shuttlequeue/models/synced.dart';
import 'package:shuttlequeue/providers/session_providers.dart';
import 'package:shuttlequeue/screens/recap_screen.dart';

/// Naipadala na ang Recap tab pero HINDI KO PA ITO NAKITANG TUMAKBO —
/// naka-hide ang browser pane, kaya walang frame ang Flutter at hindi ako
/// makapag-click. Ito ang kapalit: pinapatakbo ang totoong screen sa test.
///
/// Ganito rin eksakto ang naging bulag na sulok noon: may test ang PURE
/// service, wala ang screen — at ang nakita ni France ay blangkong screen.
final _date = DateTime(2026, 9, 5, 20);

Session _session() => Session(
      id: 's1',
      ownerUid: 'qm',
      clubId: 'c1',
      title: 'Salamat sa Laro',
      venue: 'Yspacio, Alapan, Imus',
      sessionDate: _date,
      status: SessionStatus.live,
      courtCount: 2,
      courtFeeCentavos: 120000,
      shuttlePriceCentavos: 10000,
      feeMode: FeeMode.perHead,
      createdAt: _date,
      updatedAt: _date,
    );

SessionPlayer _player(
  String name, {
  int games = 0,
  SkillTier tier = SkillTier.intermediate,
  int shuttles = 0,
}) =>
    SessionPlayer(
      id: 'id-$name',
      name: name,
      skillTier: tier,
      gamesPlayed: games,
      waitingSince: _date,
      status: PlayerStatus.queued,
      shuttlesUsed: shuttles,
      hasPaid: false,
      createdAt: _date,
    );

GameMatch _match(List<String> a, List<String> b, int afterMinutes) => GameMatch(
      id: '${a.join()}-${b.join()}-$afterMinutes',
      courtId: 'c1',
      teamA: a.map((n) => 'id-$n').toList(),
      teamB: b.map((n) => 'id-$n').toList(),
      startedAt: _date.add(Duration(minutes: afterMinutes)),
      endedAt: _date.add(Duration(minutes: afterMinutes + 15)),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<SessionPlayer> players,
  required List<GameMatch> matches,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider('s1').overrideWith((ref) => Stream.value(_session())),
        playersProvider('s1')
            .overrideWith((ref) => Stream.value(Synced.settled(players))),
        matchesProvider('s1').overrideWith((ref) => Stream.value(matches)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecapScreen(sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('walang laro pa: may paliwanag, hindi blangko', (tester) async {
    await _pump(tester, players: [_player('Ana')], matches: const []);

    expect(find.text('Nothing to recap yet'), findsOneWidget);
    // Walang share button kung walang isasalo-salo.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('pagkatapos ng gabi: nakikita ang bawat manlalaro',
      (tester) async {
    await _pump(
      tester,
      players: [
        _player('Ana', games: 2, shuttles: 1),
        _player('Ben', games: 2),
        _player('Carlo', games: 1),
        _player('Dina', games: 1),
      ],
      matches: [
        _match(['Ana', 'Ben'], ['Carlo', 'Dina'], 0),
        _match(['Ana', 'Carlo'], ['Ben', 'Dina'], 20),
      ],
    );

    for (final name in ['Ana', 'Ben', 'Carlo', 'Dina']) {
      expect(find.text(name), findsOneWidget, reason: 'nawawala si $name');
    }
    expect(find.text('Share the night'), findsOneWidget);
  });

  testWidgets('R-16: walang skill tier sa buod — nasa group chat ito',
      (tester) async {
    await _pump(
      tester,
      players: [
        _player('Ana', games: 1, tier: SkillTier.advanced),
        _player('Ben', games: 1, tier: SkillTier.beginner),
        _player('Carlo', games: 1, tier: SkillTier.advanced),
        _player('Dina', games: 1, tier: SkillTier.beginner),
      ],
      matches: [
        _match(['Ana', 'Ben'], ['Carlo', 'Dina'], 0),
      ],
    );

    // Kahihiyan ito kapag na-screenshot: "Ben — Beginner".
    for (final tier in ['Beginner', 'Intermediate', 'Advanced']) {
      expect(find.textContaining(tier), findsNothing, reason: 'R-16: $tier');
    }
  });

  testWidgets('ang hindi nakalaro ay nakikita pa rin, hindi itinatago',
      (tester) async {
    await _pump(
      tester,
      players: [
        _player('Ana', games: 1),
        _player('Ben', games: 1),
        _player('Carlo', games: 1),
        _player('Dina', games: 1),
        _player('Emman'), // dumating, hindi nakalaro — dapat makita ito ng QM
      ],
      matches: [
        _match(['Ana', 'Ben'], ['Carlo', 'Dina'], 0),
      ],
    );

    expect(find.text('Emman'), findsOneWidget);
  });

  testWidgets('walang ranking — ayon sa pangalan ang pagkakasunod',
      (tester) async {
    // Sinasadya: ang ranking ng oras sa court ay pinagsisimulan ng away sa
    // isang social club. Kung mauna si Zeny dahil pinakamarami siyang laro,
    // may nasira tayo.
    await _pump(
      tester,
      players: [
        _player('Zeny', games: 2),
        _player('Ana', games: 1),
        _player('Ben', games: 1),
        _player('Carlo', games: 2),
      ],
      matches: [
        _match(['Zeny', 'Carlo'], ['Ana', 'Ben'], 0),
        _match(['Zeny', 'Carlo'], ['Ana', 'Ben'], 20),
      ],
    );

    final anaY = tester.getTopLeft(find.text('Ana')).dy;
    final zenyY = tester.getTopLeft(find.text('Zeny')).dy;
    expect(anaY, lessThan(zenyY), reason: 'pangalan ang sunod-sunod');
  });
}
