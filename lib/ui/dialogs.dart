import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/templates.dart';
import 'common.dart';

Future<void> addProgramDialog(BuildContext context, WidgetRef ref) async {
  final title = TextEditingController(), goal = TextEditingController();
  String? target;
  await showFormDialog(
    context,
    title: 'New program',
    fields: (setState) => [
      Field(title, 'Program', autofocus: true, hint: 'Cloud engineer'),
      Field(goal, 'Goal', lines: 2, hint: 'What will you be able to do?'),
      DatePick(label: 'Target date', value: target, onChanged: (d) => setState(() => target = d)),
    ],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Give the program a name.';
      await ref.mutate(
        (s) => s.book.addProgram(title.text.trim(), goal.text.trim(), today: today(), target: target),
      );
      return null;
    },
  );
}

Future<void> templateDialog(BuildContext context, WidgetRef ref) async {
  final picked = await showModalBottomSheet<ProgramTemplate>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in programTemplates)
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(t.title),
              subtitle: Text(
                '${t.courses.length} courses · ${t.courses.fold(0, (a, c) => a + c.topics.length)} topics · ${t.goal}',
              ),
              onTap: () => Navigator.pop(context, t),
            ),
        ],
      ),
    ),
  );
  if (picked == null) return;
  await ref.mutate((s) => s.book.importTemplate(picked, today: today()));
  if (context.mounted) showMessage(context, '${picked.title} added. Edit anything to make it yours.');
}

Future<void> addCourseDialog(BuildContext context, WidgetRef ref, {String? programId}) async {
  final title = TextEditingController(), provider = TextEditingController();
  final url = TextEditingController(), hours = TextEditingController();
  var kind = 'course';
  String? due;
  await showFormDialog(
    context,
    title: 'New course',
    fields: (setState) => [
      Field(title, 'Title', autofocus: true),
      Choice(label: 'Kind', value: kind, options: courseKinds, onChanged: (v) => setState(() => kind = v)),
      Field(provider, 'Provider', hint: 'A course site, a book, your own'),
      Field(url, 'Link'),
      Field(hours, 'Estimated hours', number: true),
      DatePick(label: 'Due', value: due, onChanged: (d) => setState(() => due = d)),
    ],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Give the course a title.';
      await ref.mutate(
        (s) => s.book.addCourse(
          title.text.trim(),
          today: today(),
          programId: programId,
          kind: kind,
          provider: provider.text.trim(),
          url: url.text.trim(),
          hours: numberIn(hours)?.round() ?? 0,
          due: due,
        ),
      );
      return null;
    },
  );
}

Future<void> addTopicDialog(BuildContext context, WidgetRef ref, String courseId) async {
  final title = TextEditingController(), minutes = TextEditingController(text: '30');
  await showFormDialog(
    context,
    title: 'New topic',
    fields: (_) => [Field(title, 'Topic', autofocus: true), Field(minutes, 'Minutes', number: true)],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Give the topic a title.';
      await ref.mutate(
        (s) => s.book.addTopic(courseId, title.text.trim(), minutes: numberIn(minutes)?.round() ?? 30),
      );
      return null;
    },
  );
}

/// Logs study time, optionally against a course.
Future<void> logSessionDialog(BuildContext context, WidgetRef ref, {String? courseId}) async {
  final courses = (await ref.read(coursesProvider.future))
      .where((c) => c.status != 'done' && c.status != 'dropped')
      .toList();
  if (!context.mounted) return;
  final minutes = TextEditingController(text: '25'), note = TextEditingController();
  var course = courseId ?? '';
  await showFormDialog(
    context,
    title: 'Log study time',
    action: 'Log',
    fields: (setState) => [
      Field(minutes, 'Minutes', number: true, autofocus: true),
      Choice<String>(
        label: 'Course',
        value: course,
        options: {
          '': 'No course',
          for (final c in courses) c.id: c.title,
          if (courseId != null && !courses.any((c) => c.id == courseId)) courseId: 'This course',
        },
        onChanged: (v) => setState(() => course = v),
      ),
      Field(note, 'What did you cover?', lines: 2),
    ],
    onSave: () async {
      final m = numberIn(minutes)?.round() ?? 0;
      if (m < 1 || m > 1440) return 'Enter minutes between 1 and 1440.';
      await ref.mutate(
        (s) => s.book.logSession(
          m,
          today: today(),
          courseId: course.isEmpty ? null : course,
          note: note.text.trim(),
        ),
      );
      return null;
    },
  );
}

Future<void> addAssessmentDialog(BuildContext context, WidgetRef ref, {String? courseId}) async {
  final title = TextEditingController(),
      score = TextEditingController(),
      max = TextEditingController(text: '100');
  await showFormDialog(
    context,
    title: 'Record a test',
    fields: (_) => [
      Field(title, 'Test', autofocus: true, hint: 'Week 3 quiz'),
      Field(score, 'Score', number: true),
      Field(max, 'Out of', number: true),
    ],
    onSave: () async {
      final sc = numberIn(score), mx = numberIn(max);
      if (title.text.trim().isEmpty) return 'Name the test.';
      if (sc == null || mx == null || mx <= 0 || sc < 0 || sc > mx) {
        return 'Score must be between 0 and the maximum.';
      }
      await ref.mutate(
        (s) => s.book.addAssessment(
          title.text.trim(),
          sc.toDouble(),
          mx.toDouble(),
          today: today(),
          courseId: courseId,
        ),
      );
      return null;
    },
  );
}

Future<void> skillDialog(BuildContext context, WidgetRef ref, {Skill? skill}) async {
  final name = TextEditingController(text: skill?.name ?? ''),
      category = TextEditingController(text: skill?.category ?? 'General');
  var level = skill?.level ?? 0, target = skill?.target ?? 3;
  await showFormDialog(
    context,
    title: skill == null ? 'New skill' : 'Edit skill',
    fields: (setState) => [
      Field(name, 'Skill', autofocus: skill == null),
      Field(category, 'Category'),
      Choice<int>(
        label: 'Level now',
        value: level,
        options: {for (final (i, l) in skillLevels.indexed) i: '$i · $l'},
        onChanged: (v) => setState(() => level = v),
      ),
      Choice<int>(
        label: 'Level aimed for',
        value: target,
        options: {for (var i = 1; i <= 5; i++) i: '$i · ${skillLevels[i]}'},
        onChanged: (v) => setState(() => target = v),
      ),
    ],
    onSave: () async {
      if (name.text.trim().isEmpty) return 'Name the skill.';
      await ref.mutate((s) async {
        final cat = category.text.trim().isEmpty ? 'General' : category.text.trim();
        if (skill == null) {
          await s.book.addSkill(
            name.text.trim(),
            today: today(),
            category: cat,
            level: level,
            target: target,
          );
        } else {
          await s.book.save(
            s.db.learnSkills,
            skill.copyWith(
              name: name.text.trim(),
              category: cat,
              level: level,
              target: target,
              updated: today(),
            ),
            skill.id,
          );
        }
      });
      return null;
    },
  );
}

Future<void> portfolioDialog(BuildContext context, WidgetRef ref, {PortfolioItem? item}) async {
  final title = TextEditingController(text: item?.title ?? ''),
      url = TextEditingController(text: item?.url ?? '');
  final skills = TextEditingController(text: item?.skills ?? ''),
      summary = TextEditingController(text: item?.summary ?? '');
  var kind = item?.kind ?? 'project';
  await showFormDialog(
    context,
    title: item == null ? 'Add to portfolio' : 'Edit portfolio item',
    fields: (setState) => [
      Field(title, 'Title', autofocus: item == null),
      Choice(label: 'Kind', value: kind, options: portfolioKinds, onChanged: (v) => setState(() => kind = v)),
      Field(url, 'Link'),
      Field(skills, 'Skills it shows', hint: 'Comma-separated, matching your skills'),
      Field(summary, 'What it is and what you did', lines: 3),
    ],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Give it a title.';
      await ref.mutate((s) async {
        if (item == null) {
          await s.book.addPortfolio(
            title.text.trim(),
            today: today(),
            kind: kind,
            url: url.text.trim(),
            skills: skills.text.trim(),
            summary: summary.text.trim(),
          );
        } else {
          await s.book.save(
            s.db.learnPortfolio,
            item.copyWith(
              title: title.text.trim(),
              kind: kind,
              url: url.text.trim(),
              skills: skills.text.trim(),
              summary: summary.text.trim(),
            ),
            item.id,
          );
        }
      });
      return null;
    },
  );
}

Future<void> editCourseDialog(BuildContext context, WidgetRef ref, Course c) async {
  final title = TextEditingController(text: c.title), provider = TextEditingController(text: c.provider);
  final url = TextEditingController(text: c.url),
      hours = TextEditingController(text: c.hours == 0 ? '' : '${c.hours}');
  var kind = c.kind;
  String? due = c.due;
  await showFormDialog(
    context,
    title: 'Edit course',
    fields: (setState) => [
      Field(title, 'Title'),
      Choice(label: 'Kind', value: kind, options: courseKinds, onChanged: (v) => setState(() => kind = v)),
      Field(provider, 'Provider'),
      Field(url, 'Link'),
      Field(hours, 'Estimated hours', number: true),
      DatePick(label: 'Due', value: due, onChanged: (d) => setState(() => due = d)),
    ],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Give the course a title.';
      await ref.mutate(
        (s) => s.book.save(
          s.db.learnCourses,
          c.copyWith(
            title: title.text.trim(),
            kind: kind,
            provider: provider.text.trim(),
            url: url.text.trim(),
            hours: numberIn(hours)?.round() ?? 0,
            due: Value(due),
          ),
          c.id,
        ),
      );
      return null;
    },
  );
}
