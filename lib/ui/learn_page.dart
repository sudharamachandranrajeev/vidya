import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/stats.dart';
import 'charts.dart';
import 'common.dart';
import 'course_page.dart';
import 'dialogs.dart';
import 'plan_import.dart';
import 'zen.dart';

class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Learn',
    banner: 'page.learn',
    actions: [
      HintIconButton(
        'action.importPlan',
        icon: Icons.playlist_add,
        label: 'Import a study plan',
        onPressed: () => importPlanDialog(context, ref),
      ),
      IconButton(
        tooltip: 'Start from a template',
        icon: const Icon(Icons.auto_stories_outlined),
        onPressed: () => templateDialog(context, ref),
      ),
    ],
    fab: FloatingActionButton.extended(
      onPressed: () => addProgramDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Program'),
    ),
    body: AsyncView(
      ref.watch(statsProvider),
      onRetry: () => ref.invalidate(statsProvider),
      builder: (s) {
        final loose = s.courses
            .where((c) => c.programId == null || !s.programs.any((p) => p.id == c.programId))
            .toList();
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.programs.isEmpty && loose.isEmpty)
                      EmptyState(
                        icon: Icons.spa_outlined,
                        title: 'Begin with a program',
                        message: 'A program is a goal, such as “Data analyst”. Start from a template or write your own.',
                        actions: [
                          FilledButton(
                            onPressed: () => templateDialog(context, ref),
                            child: const Text('Use a template'),
                          ),
                          OutlinedButton(
                            onPressed: () => importPlanDialog(context, ref),
                            child: const Text('Import a plan'),
                          ),
                          OutlinedButton(
                            onPressed: () => addProgramDialog(context, ref),
                            child: const Text('New program'),
                          ),
                        ],
                      ),
                    for (final p in s.programs) _ProgramCard(s, p),
                    if (loose.isNotEmpty)
                      SectionCard(
                        title: 'Self-study',
                        trailing: IconButton(
                          tooltip: 'New course',
                          icon: const Icon(Icons.add),
                          onPressed: () => addCourseDialog(context, ref),
                        ),
                        child: Column(children: [for (final c in loose) CourseTile(s, c)]),
                      )
                    else if (s.programs.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => addCourseDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Course outside a program'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard(this.s, this.p);
  final Stats s;
  final Program p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final courses = s.courses.where((c) => c.programId == p.id).toList();
    final progress = s.programProgress(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgramPage(p.id))),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Ring(
                  value: progress,
                  size: 64,
                  stroke: 7,
                  child: Text('${(progress * 100).round()}%', style: t.labelMedium?.merge(tabular)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: t.titleMedium),
                      if (p.goal.isNotEmpty)
                        Text(
                          p.goal,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium?.copyWith(color: muted(context)),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '${courses.where((c) => c.status == 'done').length} of ${courses.length} courses'
                        '${p.target == null ? '' : ' · target ${niceDate(p.target!)}'}'
                        '${p.status == 'done'
                            ? ' · complete'
                            : p.status == 'paused'
                            ? ' · paused'
                            : ''}',
                        style: t.bodySmall?.copyWith(color: muted(context)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A course row with its progress; opens the course.
class CourseTile extends StatelessWidget {
  const CourseTile(this.s, this.c, {super.key});
  final Stats s;
  final Course c;

  @override
  Widget build(BuildContext context) {
    final topics = s.topicsOf(c.id);
    final done = topics.where((t) => t.done != null).length;
    final icon = switch (c.status) {
      'done' => Icons.check_circle,
      'doing' => Icons.play_circle_outline,
      'dropped' => Icons.remove_circle_outline,
      _ => Icons.radio_button_unchecked,
    };
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            icon,
            color: c.status == 'done' ? Theme.of(context).colorScheme.primary : muted(context),
          ),
          title: Text(
            c.title,
            style: c.status == 'dropped' ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
          ),
          subtitle: Text(
            [
              courseKinds[c.kind] ?? c.kind,
              if (topics.isNotEmpty) '$done of ${topics.length} topics',
              if (c.hours > 0) '${c.hours} h',
              if (c.due != null && c.status != 'done') 'due ${relativeDay(c.due!, s.today)}',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoursePage(c.id))),
        ),
        if (topics.isNotEmpty && c.status != 'dropped')
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: LinearProgressIndicator(value: s.courseProgress(c), minHeight: 4),
          ),
      ],
    );
  }
}

class ProgramPage extends ConsumerWidget {
  const ProgramPage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsProvider);
    return Backdrop(
      child: AsyncView(
        async,
        builder: (s) {
          final p = s.programs.where((x) => x.id == id).firstOrNull;
          if (p == null) return const Scaffold(body: Center(child: Text('This program was deleted.')));
          final courses = s.courses.where((c) => c.programId == id).toList();
          final t = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(
              title: Text(p.title),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      if (!await askSure(
                            context,
                            'Delete program?',
                            'Its courses and topics are deleted too. Study time you logged is kept.',
                          ) ||
                          !context.mounted) {
                        return;
                      }
                      await ref.mutate((x) => x.book.removeProgram(id));
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      await ref.mutate((x) => x.book.save(x.db.learnPrograms, p.copyWith(status: v), id));
                    }
                  },
                  itemBuilder: (_) => [
                    if (p.status != 'active')
                      const PopupMenuItem(value: 'active', child: Text('Mark active')),
                    if (p.status == 'active') const PopupMenuItem(value: 'paused', child: Text('Pause')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => addCourseDialog(context, ref, programId: id),
              icon: const Icon(Icons.add),
              label: const Text('Course'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (p.goal.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(p.goal, style: t.bodyLarge),
                          ),
                        Meter(
                          'Overall',
                          s.programProgress(p),
                          trailing: '${(s.programProgress(p) * 100).round()}%',
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          title: 'Courses',
                          child: courses.isEmpty
                              ? const Text('No courses yet.')
                              : Column(children: [for (final c in courses) CourseTile(s, c)]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
