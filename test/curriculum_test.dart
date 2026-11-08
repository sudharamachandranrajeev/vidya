import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/domain/book.dart';
import 'package:vidya/domain/cloze.dart';
import 'package:vidya/domain/curriculum.dart';

import 'support.dart';

const today = '2026-11-08';

String plan(Map<String, Object?> extra) => jsonEncode({
  'format': 'vidya-curriculum',
  'version': 1,
  'program': {'title': 'P', 'goal': 'G', 'targetDate': '2027-01-23'},
  ...extra,
});

void main() {
  group('parseCurriculum', () {
    test('reads a chat reply wrapped in prose and ``` fences, with trailing commas', () {
      final p = parseCurriculum('''
Sure! Here is your plan:
```json
{
  "format": "vidya-curriculum", "version": 1,
  "program": { "title": "Spanish A2", "goal": "Hold a conversation" },
  "courses": [
    { "title": "Basics", "kind": "weird", "startWeek": 3, "dueWeek": 1,
      "topics": ["Greetings", { "title": "Numbers", "minutes": 9999, "resources": [{"title": "Book", "url": "https://x"}, "Site"] },], },
  ],
  "cards": [ { "course": "Basics", "front": "Hola", "back": "Hello" }, { "front": "No back" } ],
}
```
Good luck!''');
      expect(p.title, 'Spanish A2');
      final c = p.courses.single;
      expect((c.kind, c.startWeek, c.dueWeek), ('course', 3, 3));
      expect(c.topics.map((t) => (t.title, t.minutes)), [('Greetings', 30), ('Numbers', 600)]);
      expect(c.topics[1].resources, ['Book — https://x', 'Site']);
      expect(c.hours, 11); // from topic minutes when not given
      expect(p.cards.single, (deck: 'Basics', course: 'Basics', front: 'Hola', back: 'Hello'));
    });

    test('cloze cards need no back; duplicate course titles keep the first', () {
      final p = parseCurriculum(
        plan({
          'courses': [
            {'title': 'A', 'hours': 2},
            {'title': 'a', 'hours': 9},
          ],
          'cards': [
            {'front': 'V = {{c1::I × R}}', 'back': ''},
          ],
          'skills': [
            'Plain',
            {'name': 'Rated', 'category': 'X', 'target': 9},
          ],
          'notes': [
            {
              'title': 'N',
              'body': 'b',
              'tags': ['x,y', 'z'],
            },
          ],
        }),
      );
      expect(p.courses.map((c) => (c.title, c.hours)), [('A', 2)]);
      expect(isCloze(p.cards.single.front), isTrue);
      expect(p.cards.single.deck, 'P');
      expect(p.skills, [
        (name: 'Plain', category: 'General', target: 3),
        (name: 'Rated', category: 'X', target: 5),
      ]);
      expect(p.notes.single.tags, 'x y, z');
      expect(p.targetDate, '2027-01-23');
    });

    test('clear messages for files it cannot use', () {
      Matcher says(String s) =>
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(s)));
      expect(() => parseCurriculum('no json here'), says('No plan found'));
      expect(() => parseCurriculum('{"program": {"title": "P"}, "courses": [{"title": '), says('cut off'));
      expect(
        () => parseCurriculum('{"program": {"title": "P"}, "courses": [{"title": "x"]}'),
        says('not valid JSON'),
      );
      expect(() => parseCurriculum('{"format": "vidya-decks", "cards": []}'), says('card file'));
      expect(() => parseCurriculum(plan({'version': 2})), says('newer Vidya'));
      expect(() => parseCurriculum('{"program": {"goal": "x"}, "courses": [{"title": "c"}]}'), says('title'));
      expect(() => parseCurriculum(plan({'courses': []})), says('no courses'));
      expect(
        () => parseCurriculum(
          plan({
            'cards': List.filled(5001, {'front': 'f', 'back': 'b'}),
          }),
        ),
        says('Too many cards'),
      );
    });

    test('the in-app prompt shows the format it asks for, and that example parses', () {
      expect(curriculumPrompt, contains('"format": "vidya-curriculum"'));
      final example = curriculumPrompt.substring(
        curriculumPrompt.indexOf('FORMAT'),
        curriculumPrompt.indexOf('RULES:'),
      );
      final p = parseCurriculum(example);
      expect(p.courses.single.topics.single.resources.single, 'Resource name — https://…');
    });

    test('parts pasted one after another read separately; missing parts are named', () {
      String part(String k, String course) =>
          '{"part": "$k", "program": {"title": "P"}, "courses": [{"title": "$course", '
          '"topics": [{"title": "Braces { } and \\"quotes\\""}]}]}';
      final plans = parseCurriculumParts(
        'Part one:\n${part('1 of 3', 'A')}\n"next part"\n${part('3 of 3', 'C')}',
      );
      expect(plans.map((p) => p.courses.single.title), ['A', 'C']);
      expect(plans.first.courses.single.topics.single.title, 'Braces { } and "quotes"');
      expect(missingParts(plans), [2]);
      expect(missingParts(parseCurriculumParts(part('1 of 1', 'A'))), isEmpty);
      // One reply is read as before, trailing commas and all.
      expect(parseCurriculumParts('{"title": "Solo", "courses": [{"title": "A"},],}').single.title, 'Solo');
    });

    test('the filled-in prompt carries the learner\'s answers instead of brackets', () {
      final p = filledCurriculumPrompt((
        goal: 'Pass exam 7612',
        source: '',
        level: 'beginner',
        hours: '6',
        deadline: '',
        other: '',
      ));
      expect(p, contains('- Goal, exam or qualification: Pass exam 7612\n'));
      expect(p, contains(': not given\n'));
      expect(p, contains('- Where I am now: beginner\n'));
      expect(p, contains('- Time I can study each week: 6\n'));
      expect(p, contains('- Deadline or exam date: none\n'));
      expect(p, isNot(contains('[for example')));
      expect(p, contains('RULES:'));
    });
  });

  group('importCurriculum', () {
    late LearningBook book;
    setUp(() async => book = LearningBook(await Store.open(memoryDatabase())));
    tearDown(() => book.db.close());

    test('the 7612 Car Inspector example imports whole, and a second import adds nothing', () async {
      final p = parseCurriculum(File('docs/examples/2026-11-08-car-inspector-7612.json').readAsStringSync());
      expect((p.courses.length, p.topicCount, p.cards.length, p.skills.length), (9, 62, 85, 7));

      final r = await book.importCurriculum(p, today: today);
      expect((r.courses, r.topics, r.cards, r.skills, r.notes), (9, 62, 85, 7, 12));

      final s = await book.stats(today);
      final program = s.programs.single;
      expect((program.title, program.target), ('Car Inspector — NYC Transit Exam 7612', '2027-01-23'));
      final apply = s.courses.firstWhere((c) => c.title.startsWith('Apply'));
      expect(apply.due, '2026-11-22'); // week 2, before the 28 Nov deadline
      expect(apply.programId, program.id);
      expect(s.courses.every((c) => c.programId == program.id), isTrue);
      expect(s.cards.every((c) => c.courseId != null && c.due == today), isTrue);
      expect(s.notes.map((n) => n.title), contains('Car Inspector — NYC Transit Exam 7612 — Roadmap'));
      final guide = s.notes.firstWhere((n) => n.title == 'Pneumatic equipment and air brakes — study guide');
      expect(guide.body, contains('Force = pressure × area'));
      expect(guide.tags, 'Car Inspector — NYC Transit Exam 7612, study guide');

      final again = await book.importCurriculum(p, today: today);
      expect((again.courses, again.topics, again.cards, again.skills, again.notes), (0, 0, 0, 0, 0));
      expect(again.programId, program.id);
    });

    test('parts merge into one program; a topic added to a known course joins it', () async {
      Future<CurriculumImport> part(List<Map<String, Object?>> courses) =>
          book.importCurriculum(parseCurriculum(plan({'courses': courses})), today: today);
      await part([
        {
          'title': 'One',
          'dueWeek': 1,
          'topics': ['a', 'b'],
        },
      ]);
      final r = await part([
        {
          'title': 'one',
          'topics': ['B', 'c'],
        },
        {'title': 'Two'},
      ]);
      expect((r.courses, r.topics), (1, 1));
      final s = await book.stats(today);
      expect(s.programs, hasLength(1));
      expect(s.courses.map((c) => c.title), ['One', 'Two']);
      expect(s.courses.first.due, '2026-11-15');
      expect(s.topics.map((t) => t.title), ['a', 'b', 'c']);
    });
  });
}
