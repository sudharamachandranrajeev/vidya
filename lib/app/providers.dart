import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../db/database.dart';
import '../domain/achievements.dart';
import '../domain/stats.dart';
import '../ui/hints.dart';
import 'session.dart';

/// The open session; main() overrides this before the first frame.
final sessionProvider = Provider<AppSession>((ref) => throw StateError('No session'));

/// What main() and the tests override: the session, under both its Vidya
/// and its shared type, and the app's identity and hints.
List<Override> vidyaOverrides(AppSession session) => [
  sessionProvider.overrideWithValue(session),
  coreSessionProvider.overrideWithValue(session),
  appIdentityProvider.overrideWithValue(vidyaIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...vidyaHints}),
  sentinelChecksProvider.overrideWithValue([...coreChecks, lockCheck]),
];

/// Whether streaks are shown: the days-in-a-row count on Home, Progress and
/// the suite summary. Off until the learner opts in, so nothing nags about a
/// broken chain. Achievements are unaffected. Device-only.
class ShowStreaks extends AsyncNotifier<bool> {
  static const _key = 'ui.streaks';

  @override
  Future<bool> build() async => await ref.watch(sessionProvider).db.localSetting(_key) == 'on';

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await ref.read(sessionProvider).db.setLocalSetting(_key, on ? 'on' : 'off');
  }
}

final showStreaksProvider = AsyncNotifierProvider<ShowStreaks, bool>(ShowStreaks.new);

/// Achievements reached by the latest write, waiting to be celebrated.
class Celebrations extends Notifier<List<Achievement>> {
  @override
  List<Achievement> build() => const [];
  void add(List<Achievement> a) => state = [...state, ...a];
  void clear() => state = const [];
}

final celebrationsProvider = NotifierProvider<Celebrations, List<Achievement>>(Celebrations.new);

extension Mutate on WidgetRef {
  /// Runs a write, refreshes the screens, queues a sync, and unlocks any
  /// achievement the write earned.
  Future<T> mutate<T>(Future<T> Function(AppSession s) write) async {
    final s = read(sessionProvider);
    final result = await write(s);
    final fresh = await s.book.unlockNew(today());
    if (fresh.isNotEmpty) read(celebrationsProvider.notifier).add(fresh);
    changed();
    return result;
  }
}

/// The rows of [table] that are not deleted, re-read after every write.
FutureProvider<List<D>> _rows<T extends SyncedRow, D>(
  TableInfo<T, D> Function(AppDatabase db) table, {
  List<OrderingTerm Function(T t)> orderBy = const [],
}) => FutureProvider<List<D>>((ref) {
  ref.watch(revisionProvider);
  final db = ref.watch(sessionProvider).db;
  final q = db.select(table(db))
    ..where((t) => t.deleted.not())
    ..orderBy(orderBy);
  return q.get();
});

final programsProvider = _rows<$LearnProgramsTable, Program>(
  (db) => db.learnPrograms,
  orderBy: [(p) => OrderingTerm.asc(p.status), (p) => OrderingTerm.desc(p.started)],
);

final coursesProvider = _rows<$LearnCoursesTable, Course>(
  (db) => db.learnCourses,
  orderBy: [(c) => OrderingTerm.asc(c.added)],
);

final skillsProvider = _rows<$LearnSkillsTable, Skill>(
  (db) => db.learnSkills,
  orderBy: [(s) => OrderingTerm.asc(s.category), (s) => OrderingTerm.asc(s.name)],
);

final portfolioProvider = _rows<$LearnPortfolioTable, PortfolioItem>(
  (db) => db.learnPortfolio,
  orderBy: [(p) => OrderingTerm.desc(p.day)],
);

final notesProvider = _rows<$LearnNotesTable, Note>(
  (db) => db.learnNotes,
  orderBy: [(n) => OrderingTerm.desc(n.updated), (n) => OrderingTerm.asc(n.title)],
);

final unlocksProvider = _rows<$LearnUnlocksTable, Unlock>((db) => db.learnUnlocks);

/// Every measure in one place; rebuilt after each write and at midnight's
/// next write (the day comes from [todayProvider]).
final statsProvider = FutureProvider<Stats>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.stats(ref.watch(todayProvider));
});
