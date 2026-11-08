import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/achievements.dart';
import '../domain/stats.dart';
import 'charts.dart';
import 'common.dart';
import 'course_page.dart';
import 'dialogs.dart';
import 'focus_page.dart';
import 'notes_page.dart';
import 'review_page.dart';
import 'zen.dart';

String _greeting() {
  final h = DateTime.now().hour;
  return h < 5
      ? 'Rest well'
      : h < 12
      ? 'Good morning'
      : h < 18
      ? 'Good afternoon'
      : 'Good evening';
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Vidya',
    banner: 'page.home',
    actions: [
      HintIconButton(
        'action.focus',
        icon: Icons.self_improvement,
        label: 'Focus',
        onPressed: () => openFocus(context),
      ),
      HintIconButton(
        'nav.home',
        icon: Icons.timer_outlined,
        label: 'Log study time',
        onPressed: () => logSessionDialog(context, ref),
      ),
    ],
    body: AsyncView(
      ref.watch(statsProvider),
      onRetry: () => ref.invalidate(statsProvider),
      builder: (s) => _Body(s),
    ),
  );
}

class _Body extends ConsumerWidget {
  const _Body(this.s);
  final Stats s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final streaks = ref.watch(showStreaksProvider).value ?? false;
    final unlocks = [...(ref.watch(unlocksProvider).value ?? const <Unlock>[])]
      ..sort((a, b) => b.day.compareTo(a.day));
    final byKey = {for (final a in achievements) a.key: a};
    final next = _upNext(s);
    final week = s.lastWeek;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final labels = [
      for (var i = 6; i >= 0; i--) days[DateTime.parse('${addDays(s.today, -i)}T00:00:00').weekday - 1],
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}.', style: t.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          !streaks || s.streak == 0
                              ? 'One small step is enough to begin.'
                              : 'Unhurried, and unbroken for ${s.streak} ${s.streak == 1 ? 'day' : 'days'}.',
                          style: t.bodyLarge?.copyWith(color: muted(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                FadeIn(
                  delay: const Duration(milliseconds: 60),
                  child: _LevelCard(s, streaks: streaks),
                ),
                const SizedBox(height: 16),
                FadeIn(delay: const Duration(milliseconds: 100), child: _Quests(s)),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'This week',
                  trailing: Text(
                    minutesText(week.fold(0, (a, b) => a + b)),
                    style: t.bodyMedium?.copyWith(color: muted(context)),
                  ),
                  child: BarChart(values: week, labels: labels, unit: ' min', height: 90),
                ),
                if (next.isNotEmpty)
                  SectionCard(
                    title: 'Up next',
                    child: Column(
                      children: [
                        for (final (course, topic) in next)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: false,
                            title: Text(topic.title),
                            subtitle: Text('${course.title} · ${minutesText(topic.minutes)}'),
                            secondary: IconButton(
                              tooltip: 'Open course',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () =>
                                  Navigator.of(context)
                                      .push(MaterialPageRoute(builder: (_) => CoursePage(course.id))),
                            ),
                            onChanged: (_) =>
                                ref.mutate((x) => x.book.setTopicDone(topic, true, today: s.today)),
                          ),
                      ],
                    ),
                  ),
                if (s.overdue.isNotEmpty)
                  SectionCard(
                    title: 'Past due',
                    child: Column(
                      children: [
                        for (final c in s.overdue)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.schedule, color: StatusColors.warning),
                            title: Text(c.title),
                            subtitle: Text(
                              'Was due ${relativeDay(c.due!, s.today)}. Move the date or let it go.',
                            ),
                            onTap: () =>
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => CoursePage(c.id))),
                          ),
                      ],
                    ),
                  ),
                if (unlocks.isNotEmpty)
                  SectionCard(
                    title: 'Recently earned',
                    child: Column(
                      children: [
                        for (final u in unlocks.take(3))
                          if (byKey[u.id] case final a?)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(a.icon, color: clay),
                              title: Text(a.title),
                              subtitle: Text('${a.description} · ${relativeDay(u.day, s.today)}'),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The next open topic of each course being studied.
  List<(Course, Topic)> _upNext(Stats s) => [
    for (final c in s.courses.where((c) => c.status == 'doing'))
      if (s.topicsOf(c.id).where((t) => t.done == null).firstOrNull case final t?) (c, t),
  ].take(4).toList();
}

class _LevelCard extends StatelessWidget {
  const _LevelCard(this.s, {required this.streaks});
  final Stats s;
  final bool streaks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stats = [
      if (streaks) (Icons.local_fire_department_outlined, '${s.streak}', 'day streak'),
      (Icons.hourglass_bottom, s.hours.toStringAsFixed(s.hours < 10 ? 1 : 0), 'hours'),
      (Icons.check_circle_outline, '${s.topicsDone}', 'topics'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 28,
          runSpacing: 20,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              label: 'Level ${s.level}, ${(s.levelProgress * 100).round()} percent to the next',
              child: Ring(
                value: s.levelProgress,
                size: 132,
                stroke: 11,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${s.level}', style: t.displaySmall?.copyWith(fontSize: 38, height: 1)),
                    Text('level', style: t.labelMedium?.copyWith(color: muted(context))),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.rank, style: t.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${s.xp - s.levelStart} of ${s.levelEnd - s.levelStart} to level ${s.level + 1}',
                    style: t.bodyMedium?.copyWith(color: muted(context)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final (icon, value, label) in stats)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 18, color: muted(context)),
                              const SizedBox(height: 4),
                              Text(value, style: t.titleLarge?.merge(tabular)),
                              Text(label, style: t.bodySmall?.copyWith(color: muted(context))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quests extends ConsumerWidget {
  const _Quests(this.s);
  final Stats s;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Today’s quests',
    trailing: Text(
      '${s.quests.where((q) => q.done).length} of ${s.quests.length}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted(context)),
    ),
    child: Column(
      children: [
        for (final q in s.quests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              q.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: q.done ? Theme.of(context).colorScheme.primary : muted(context),
            ),
            title: Text(
              q.title,
              style: q.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
            ),
            subtitle: q.done || q.detail == null ? null : Text(q.detail!),
            trailing: Text('+${q.xp} xp', style: TextStyle(color: q.done ? null : clay)),
            onTap: q.done
                ? null
                : switch (q.id) {
                    'study' => () => openFocus(context),
                    'review' => () => startReview(context),
                    'note' => () => noteEditor(context, ref),
                    _ => null,
                  },
          ),
      ],
    ),
  );
}
