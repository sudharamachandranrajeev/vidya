import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/curriculum.dart';
import 'common.dart';

/// Imports a whole study plan: let a connected AI write it, or copy the
/// prompt into any AI chat and paste the reply (or open a saved file); check
/// what it holds; import.
Future<void> importPlanDialog(BuildContext context, WidgetRef ref) async {
  final reply = TextEditingController();
  var plans = <CurriculumPlan>[];
  String? problem;
  void read() {
    plans = [];
    problem = null;
    if (reply.text.trim().isEmpty) return;
    try {
      plans = parseCurriculumParts(reply.text);
    } on FormatException catch (e) {
      problem = e.message;
    }
  }

  String? done;
  await showFormDialog(
    context,
    title: 'Import a study plan',
    action: 'Import',
    fields: (setState) {
      final t = Theme.of(context).textTheme;
      final missing = missingParts(plans);
      int sum(int Function(CurriculumPlan p) f) => plans.fold(0, (a, p) => a + f(p));
      return [
        Text(
          '1. Let your AI write the plan, or copy the prompt, fill in the brackets and send it to any AI chat.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Make it with AI'),
              onPressed: () async {
                final made = await showDialog<String>(
                  context: context,
                  builder: (_) => const _MakePlanDialog(),
                );
                if (made == null) return;
                setState(() {
                  reply.text = made;
                  read();
                });
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.content_copy),
              label: const Text('Copy AI prompt'),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: curriculumPrompt));
                if (context.mounted) showMessage(context, 'Prompt copied. Paste it into an AI chat.');
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '2. Paste the whole reply here (every part, one after another), or open a saved plan file.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: reply,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'AI reply',
            hintText: '{ "format": "vidya-curriculum", … }',
          ),
          onChanged: (_) => setState(read),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Open a file'),
            onPressed: () async {
              final file = await FilePicker.pickFile(
                dialogTitle: 'Open a study plan',
                type: FileType.custom,
                allowedExtensions: const ['json', 'txt'],
              );
              if (file == null) return;
              final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
              setState(() {
                reply.text = text;
                read();
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        if (plans case [final p, ...])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: t.titleMedium),
                  if (p.goal.isNotEmpty) Text(p.goal, style: t.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (plans.length > 1)
                        '${plans.length} parts'
                      else if (p.part.isNotEmpty)
                        'Part ${p.part}',
                      '${sum((p) => p.courses.length)} courses',
                      '${sum((p) => p.topicCount)} topics',
                      '${sum((p) => p.cards.length)} cards',
                      '${sum((p) => p.skills.length)} skills',
                      '${sum((p) => p.notes.length)} notes',
                      if (p.targetDate != null) 'target ${niceDate(p.targetDate!)}',
                    ].join(' · '),
                  ),
                  if (missing.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${missing.length == 1 ? 'Part ${missing.single} is' : 'Parts ${missing.join(', ')} are'} '
                        'missing. Ask the AI for "next part" and paste it after this one, or import '
                        'now and add the rest later.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (problem != null)
          Text(problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ];
    },
    onSave: () async {
      read();
      if (plans.isEmpty) return problem ?? 'Paste the AI reply first.';
      final parts = plans;
      final r = await ref.mutate((s) async {
        var total = (courses: 0, topics: 0, skills: 0, cards: 0, notes: 0);
        // Parts merge by title, so importing them one by one builds one program.
        for (final p in parts) {
          final x = await s.book.importCurriculum(p, today: today());
          total = (
            courses: total.courses + x.courses,
            topics: total.topics + x.topics,
            skills: total.skills + x.skills,
            cards: total.cards + x.cards,
            notes: total.notes + x.notes,
          );
        }
        return total;
      });
      done =
          '${parts.first.title}: ${r.courses} courses, ${r.topics} topics, ${r.cards} cards, '
          '${r.skills} skills and ${r.notes} notes added.'
          '${r.notes > 0 ? ' Topic details are in Notes.' : ''}';
      return null;
    },
  );
  if (done != null && context.mounted) showMessage(context, done!);
}

/// Asks the AI chosen for Ask AI to write the plan, part after part, and
/// returns the replies for the import box. A chat website cannot answer
/// here, so then it copies the filled-in prompt instead.
class _MakePlanDialog extends ConsumerStatefulWidget {
  const _MakePlanDialog();

  @override
  ConsumerState<_MakePlanDialog> createState() => _MakePlanDialogState();
}

class _MakePlanDialogState extends ConsumerState<_MakePlanDialog> {
  static const _system =
      'You write study plans for Vidya, a learning app. Follow the user\'s format exactly and '
      'reply with one JSON object only.';
  static const _maxParts = 12;

  final _goal = TextEditingController();
  final _source = TextEditingController();
  final _level = TextEditingController();
  final _hours = TextEditingController();
  final _deadline = TextEditingController();
  final _other = TextEditingController();
  String? _status, _error;

  /// Parts written before an error, handed back on Close.
  String? _kept;

  @override
  void dispose() {
    for (final c in [_goal, _source, _level, _hours, _deadline, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _prompt => filledCurriculumPrompt((
    goal: _goal.text,
    source: _source.text,
    level: _level.text,
    hours: _hours.text,
    deadline: _deadline.text,
    other: _other.text,
  ));

  Future<void> _make(HelpAiSetup setup) async {
    if (_goal.text.trim().isEmpty) {
      setState(() => _error = 'Say what the plan is for first.');
      return;
    }
    if (setup.via == HelpAi.chat) {
      await Clipboard.setData(ClipboardData(text: _prompt));
      if (!mounted) return;
      showMessage(
        context,
        'Prompt copied with your answers. Paste it into an AI chat, then paste the reply here.',
      );
      Navigator.pop(context);
      return;
    }
    setState(() {
      _status = 'Writing the plan. This can take a few minutes…';
      _error = null;
    });
    final turns = <HelpTurn>[(user: true, text: _prompt)];
    final replies = <String>[];
    try {
      final asker = await ref.read(helpAskerProvider)(setup);
      while (replies.length < _maxParts) {
        final answer = await asker.ask(_system, turns);
        if (!mounted) return;
        replies.add(answer.trim());
        final List<CurriculumPlan> plans;
        try {
          plans = parseCurriculumParts(replies.join('\n\n'));
        } on FormatException {
          break; // The import box explains what is wrong with it.
        }
        final next = missingParts(plans);
        if (next.isEmpty) break;
        setState(() => _status = 'Writing part ${next.first} of ${next.last}…');
        turns
          ..add((user: false, text: answer))
          ..add((user: true, text: 'next part'));
      }
      if (mounted) Navigator.pop(context, replies.join('\n\n'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = null;
        _error = replies.isEmpty
            ? describeError(e)
            : '${describeError(e)} The parts written so far are kept: close this to import them.';
      });
      if (replies.isNotEmpty) _kept = replies.join('\n\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(helpAiProvider).value ?? const HelpAiSetup();
    final theme = Theme.of(context);
    final busy = _status != null;
    final chat = setup.via == HelpAi.chat;
    Widget field(TextEditingController c, String label, {String? hint, int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        enabled: !busy,
        minLines: 1,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
    return AlertDialog(
      title: const Text('Make a plan with AI'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Written by: ${setup.via.label}', style: theme.textTheme.bodyMedium)),
                TextButton(
                  onPressed: busy ? null : () => showAskAiSetup(context),
                  child: const Text('Change'),
                ),
              ],
            ),
            if (chat)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'A chat website cannot send the plan back to Vidya, so this copies the prompt with your '
                  'answers for you to paste there. To have the plan written right here, choose Change and '
                  'connect an AI.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            field(_goal, 'What the plan is for', hint: 'Pass NYC Transit exam 7612, Car Inspector'),
            field(
              _source,
              'Syllabus or source material (optional)',
              hint: 'Paste the exam notice or book contents',
              lines: 6,
            ),
            field(_level, 'Where you are now (optional)', hint: 'Beginner, some experience…'),
            field(_hours, 'Hours a week (optional)', hint: '6'),
            field(_deadline, 'Deadline or exam date (optional)', hint: 'yyyy-mm-dd'),
            field(_other, 'Anything else (optional)', hint: 'Weak areas, preferred resources, language'),
            if (_status case final status?)
              Row(
                children: [
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(status)),
                ],
              ),
            if (_error case final error?) Text(error, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Text(
              'What you type here is sent to ${setup.via.label}. Your notes, cards and progress are not.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _kept), child: const Text('Close')),
        FilledButton(
          onPressed: busy ? null : () => _make(setup),
          child: Text(chat ? 'Copy prompt' : 'Write the plan'),
        ),
      ],
    );
  }
}
