import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'ui/hints.dart';
import 'ui/zen.dart';

/// Vidya as the Brahma suite app hosts it.
final vidyaSuite = SuiteApp(
  identity: vidyaIdentity,
  tagline: 'Learning and knowledge',
  icon: Icons.school_outlined,
  open: AppSession.open,
  overrides: (s) => [sessionProvider.overrideWithValue(s as AppSession)],
  hints: vidyaHints,
  theme: (_, b) => vidyaTheme(b),
  home: (onHome) => VidyaHome(onHome: onHome),
  builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
  summary: (_) => const _Summary(),
);

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(statsProvider).value;
    if (s == null) return const SizedBox(height: 48);
    final streaks = ref.watch(showStreaksProvider).value ?? false;
    return SummaryFigures([
      if (streaks) ('${s.streak}', 'day streak'),
      ('${s.todayMinutes} min', 'studied today'),
      ('${s.level}', 'level · ${s.rank}'),
    ], next: s.courses.isEmpty ? 'Add a course to start learning.' : null);
  }
}
