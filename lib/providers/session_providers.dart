import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill_line.dart';
import '../models/club_member.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/session.dart';
import '../models/session_player.dart';
import '../models/synced.dart';
import '../repositories/club_repository.dart';
import '../repositories/match_repository.dart';
import '../repositories/player_repository.dart';
import '../repositories/session_repository.dart';
import '../services/matchmaking_service.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';
import 'sync_error_provider.dart';

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
    onDeferredWriteError: (error) =>
        ref.read(syncErrorProvider.notifier).report(error),
  ),
);

final clubRepositoryProvider = Provider<ClubRepository>(
  (ref) => ClubRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

/// Ang uid ng naka-login na QM, o null. Maliit na provider pero mahalaga:
/// dito nakasalalay ang lahat ng ownership-scoped na query.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateChangesProvider).value?.uid,
);

/// Ang default club ng QM — ginagawa sa unang pangangailangan.
/// Ang `.future` nito ang hinihintay bago gumawa ng session.
final defaultClubIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;

  final displayName = user.displayName?.trim();
  final fallbackName = (displayName == null || displayName.isEmpty)
      ? 'My club'
      : "$displayName's club";

  return ref.watch(clubRepositoryProvider).ensureDefaultClub(
        ownerUid: user.uid,
        fallbackName: fallbackName,
      );
});

/// Lahat ng session ng kasalukuyang QM, kasama ang sync status.
///
/// Isang listener lang ito para sa buong app — pinagsasaluhan ng bawat
/// widget na nanonood. Kaya hindi lumalobo ang read count (R-12).
final sessionsProvider = StreamProvider<Synced<List<Session>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    return Stream.value(const Synced<List<Session>>.settled([]));
  }
  return ref.watch(sessionRepositoryProvider).watchSessions(uid);
});

/// Isang partikular na session, sinusubaybayan nang live.
final sessionProvider = StreamProvider.family<Session?, String>((ref, id) {
  return ref.watch(sessionRepositoryProvider).watchSession(id);
});

/// Ang regulars book ng default club.
final clubMembersProvider = StreamProvider<List<ClubMember>>((ref) {
  final clubId = ref.watch(defaultClubIdProvider).value;
  if (clubId == null) return Stream.value(const <ClubMember>[]);
  return ref.watch(clubRepositoryProvider).watchMembers(clubId);
});

// ---------------------------------------------------------------------------
// Players
// ---------------------------------------------------------------------------

final playerRepositoryProvider = Provider<PlayerRepository>(
  (ref) => PlayerRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

/// Mga manlalaro ng isang session. Isang listener kada session, ibinabahagi
/// ng roster screen, courts screen at cost-split screen.
final playersProvider =
    StreamProvider.family<Synced<List<SessionPlayer>>, String>((ref, sessionId) {
  return ref.watch(playerRepositoryProvider).watchPlayers(sessionId);
});

// ---------------------------------------------------------------------------
// Courts, matches at ang mungkahi ng algorithm
// ---------------------------------------------------------------------------

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

final courtsProvider =
    StreamProvider.family<Synced<List<Court>>, String>((ref, sessionId) {
  return ref.watch(matchRepositoryProvider).watchCourts(sessionId);
});

final matchesProvider =
    StreamProvider.family<List<GameMatch>, String>((ref, sessionId) {
  return ref.watch(matchRepositoryProvider).watchMatches(sessionId);
});

/// Mga laro na kasalukuyang tumatakbo, naka-index ayon sa court.
final liveMatchesProvider =
    Provider.family<Map<String, GameMatch>, String>((ref, sessionId) {
  final matches = ref.watch(matchesProvider(sessionId)).value ?? const [];
  return {
    for (final match in matches.where((m) => m.isInProgress))
      match.courtId: match,
  };
});

final matchmakingServiceProvider = Provider<MatchmakingService>(
  (ref) => const MatchmakingService(),
);

/// Ang pila, ayon sa parehong panuntunan ng fairness na ginagamit ng
/// algorithm — kaya walang pagkakaiba ang nakikita ng QM sa nangyayari.
final queueOrderProvider =
    Provider.family<List<SessionPlayer>, String>((ref, sessionId) {
  final players = ref.watch(playersProvider(sessionId)).value?.data ?? const [];
  return queueOrder(players);
});

/// Mga naka-freeze na halaga ng bayarin (R-09). Walang laman kapag hindi
/// pa naka-lock — live pa ang kuwenta noon.
final billProvider =
    StreamProvider.family<List<BillLine>, String>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).watchBill(sessionId);
});
