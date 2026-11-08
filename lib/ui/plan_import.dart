import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/curriculum.dart';
import 'common.dart';

/// Imports a whole study plan: copy the prompt into any AI chat, paste the
/// reply (or open a saved file), check what it holds, import.
Future<void> importPlanDialog(BuildContext context, WidgetRef ref) async {
  final reply = TextEditingController();
  CurriculumPlan? plan;
  String? problem;
  void read() {
    plan = null;
    problem = null;
    if (reply.text.trim().isEmpty) return;
    try {
      plan = parseCurriculum(reply.text);
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
      final p = plan;
      return [
        Text('1. Copy the prompt, fill in the brackets and send it to any AI chat.', style: t.bodyMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.content_copy),
            label: const Text('Copy AI prompt'),
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: curriculumPrompt));
              if (context.mounted) showMessage(context, 'Prompt copied. Paste it into an AI chat.');
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('2. Paste the whole reply here, or open a saved plan file.', style: t.bodyMedium),
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
        if (p != null)
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
                      if (p.part.isNotEmpty) 'Part ${p.part}',
                      '${p.courses.length} courses',
                      '${p.topicCount} topics',
                      '${p.cards.length} cards',
                      '${p.skills.length} skills',
                      '${p.notes.length} notes',
                      if (p.targetDate != null) 'target ${niceDate(p.targetDate!)}',
                    ].join(' · '),
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
      final p = plan;
      if (p == null) return problem ?? 'Paste the AI reply first.';
      final r = await ref.mutate((s) => s.book.importCurriculum(p, today: today()));
      done =
          '${p.title}: ${r.courses} courses, ${r.topics} topics, ${r.cards} cards, '
          '${r.skills} skills and ${r.notes} notes added.'
          '${r.notes > 0 ? ' Topic details are in Notes.' : ''}';
      return null;
    },
  );
  if (done != null && context.mounted) showMessage(context, done!);
}
