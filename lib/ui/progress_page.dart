import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/stats.dart';
import 'charts.dart';
import 'common.dart';
import 'zen.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Progress',
    banner: 'page.progress',
    body: AsyncView(
      ref.watch(statsProvider),
      onRetry: () => ref.invalidate(statsProvider),
      builder: (s) => _Body(s, streaks: ref.watch(showStreaksProvider).value ?? false),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body(this.s, {required this.streaks});
  final Stats s;
  final bool streaks;

  @override
  Widget build(BuildContext context) {
    final weeks = s.weeklyMinutes();
    final labels = [for (var w = 7; w >= 0; w--) w == 0 ? 'now' : '-${w}w'];
    final avg = s.averageScore;
    final onTime = s.onTimeRate;
    final gaps = s.skills.where((k) => k.level < k.target).toList()
      ..sort((a, b) => (b.target - b.level).compareTo(a.target - a.level));
    String pct(double v) => '${(v * 100).round()}%';
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TileGrid(
                  minWidth: 150,
                  children: [
                    KpiTile(
                      label: 'Experience',
                      value: '${s.xp}',
                      icon: Icons.auto_awesome_outlined,
                      caption: 'Level ${s.level} · ${s.rank}',
                    ),
                    KpiTile(
                      label: 'Study time',
                      value: s.hours.toStringAsFixed(1),
                      icon: Icons.hourglass_bottom,
                      caption: 'hours in total',
                    ),
                    if (streaks)
                      KpiTile(
                        label: 'Streak',
                        value: '${s.streak}',
                        icon: Icons.local_fire_department_outlined,
                        caption: 'best ${s.longestStreak} days',
                      ),
                    KpiTile(
                      label: 'Consistency',
                      value: pct(s.consistency),
                      icon: Icons.self_improvement,
                      caption: '${s.activeDaysIn(30)} of the last 30 days',
                    ),
                    KpiTile(
                      label: 'Topics done',
                      value: '${s.topicsDone}',
                      icon: Icons.check_circle_outline,
                      caption: 'of ${s.topics.length}',
                    ),
                    KpiTile(
                      label: 'Courses done',
                      value: '${s.coursesDone}',
                      icon: Icons.menu_book_outlined,
                      caption: '${s.coursesDoing} in progress',
                    ),
                    KpiTile(
                      label: 'Average score',
                      value: avg == null ? '–' : '${avg.round()}%',
                      icon: Icons.quiz_outlined,
                      caption: '${s.assessments.length} tests',
                    ),
                    KpiTile(
                      label: 'On time',
                      value: onTime == null ? '–' : pct(onTime),
                      icon: Icons.event_available_outlined,
                      caption: onTime == null
                          ? 'No dated courses finished'
                          : 'courses finished by their date',
                    ),
                    KpiTile(
                      label: 'Skill mastery',
                      value: pct(s.mastery),
                      icon: Icons.track_changes,
                      caption: '${s.skillsAtTarget} of ${s.skills.length} at target',
                    ),
                    KpiTile(
                      label: 'Portfolio',
                      value: '${s.portfolioScore}',
                      icon: Icons.folder_special_outlined,
                      caption: '${s.portfolio.length} items, ${s.portfolioKinds} kinds',
                    ),
                    KpiTile(
                      label: 'Notes',
                      value: '${s.notes.length}',
                      icon: Icons.edit_note,
                      caption: 'in your knowledge base',
                    ),
                    KpiTile(
                      label: 'Retention',
                      value: s.retention == null ? '–' : pct(s.retention!),
                      icon: Icons.psychology_outlined,
                      caption: '${s.reviewsTotal} reviews · ${s.matureCards} cards held',
                    ),
                    KpiTile(
                      label: 'Longest focus',
                      value: minutesText(s.longestSession),
                      icon: Icons.self_improvement,
                      caption: 'in one sitting',
                    ),
                    KpiTile(
                      label: 'Programs',
                      value: '${s.programsDone}/${s.programs.length}',
                      icon: Icons.emoji_events_outlined,
                      caption: 'complete',
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Study time by week',
                  trailing: Text(
                    '${minutesText(weeks.fold(0, (a, b) => a + b))} in 8 weeks',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted(context)),
                  ),
                  child: BarChart(values: weeks, labels: labels, unit: ' min'),
                ),
                SectionCard(
                  title: 'Test scores',
                  child: s.assessments.isEmpty
                      ? const Text('Record a test on a course to see the trend.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Sparkline(s.scoreTrend, height: 96),
                            const SizedBox(height: 8),
                            Text(
                              'Best ${s.bestScore.round()}% · average ${avg!.round()}%',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted(context)),
                            ),
                          ],
                        ),
                ),
                SectionCard(
                  title: 'Skill gaps',
                  child: gaps.isEmpty
                      ? Text(
                          s.skills.isEmpty
                              ? 'Add skills to see where to focus.'
                              : 'Every skill is at its target. Raise a target when you are ready.',
                        )
                      : Column(
                          children: [
                            for (final k in gaps.take(8))
                              Meter(k.name, k.level / k.target, trailing: 'level ${k.level} of ${k.target}'),
                          ],
                        ),
                ),
                SectionCard(
                  title: 'Time by course',
                  child: Builder(
                    builder: (_) {
                      final rows = [
                        for (final c in s.courses)
                          if (s.hoursOn(c.id) > 0) (c.title, s.hoursOn(c.id)),
                      ]..sort((a, b) => b.$2.compareTo(a.$2));
                      if (rows.isEmpty) {
                        return const Text('Log study time against a course to see where it goes.');
                      }
                      final top = rows.first.$2;
                      return Column(
                        children: [
                          for (final r in rows.take(6))
                            Meter(r.$1, r.$2 / top, trailing: '${r.$2.toStringAsFixed(1)} h'),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
