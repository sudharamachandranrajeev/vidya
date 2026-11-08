import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';

import 'cloze.dart';

/// A whole study plan in one file: a program, its roadmap of courses with
/// topics, the skills it builds, flashcards and notes. Learners get one by
/// pasting [curriculumPrompt] into any AI chat and pasting the reply back, or
/// by opening a saved `.json` file. Nothing here touches the database; see
/// `LearningBook.importCurriculum`.

class PlanTopic {
  const PlanTopic(this.title, {this.minutes = 30, this.details = '', this.resources = const []});
  final String title;
  final int minutes;
  final String details;
  final List<String> resources;
}

class PlanCourse {
  const PlanCourse(
    this.title, {
    this.kind = 'course',
    this.hours = 0,
    this.provider = '',
    this.url = '',
    this.startWeek,
    this.dueWeek,
    this.summary = '',
    this.topics = const [],
  });
  final String title, kind, provider, url, summary;
  final int hours;

  /// Weeks from the day of import; [dueWeek] sets the course's due date.
  final int? startWeek, dueWeek;
  final List<PlanTopic> topics;

  /// Whether the course carries more than its topic titles, worth a note.
  bool get hasGuide =>
      summary.isNotEmpty || topics.any((t) => t.details.isNotEmpty || t.resources.isNotEmpty);
}

typedef PlanSkill = ({String name, String category, int target});
typedef PlanCard = ({String deck, String course, String front, String back});
typedef PlanNote = ({String title, String body, String tags});

class CurriculumPlan {
  const CurriculumPlan({
    required this.title,
    this.goal = '',
    this.targetDate,
    this.part = '',
    this.courses = const [],
    this.skills = const [],
    this.cards = const [],
    this.notes = const [],
  });
  final String title, goal, part;

  /// yyyy-MM-dd, or null.
  final String? targetDate;
  final List<PlanCourse> courses;
  final List<PlanSkill> skills;
  final List<PlanCard> cards;
  final List<PlanNote> notes;

  int get topicCount => courses.fold(0, (a, c) => a + c.topics.length);
}

const curriculumFormat = 'vidya-curriculum';

// Limits keep a runaway or hostile file from flooding the database.
const _maxCourses = 100, _maxTopics = 300, _maxCards = 5000, _maxNotes = 300, _maxSkills = 200;
const _maxTitle = 200, _maxText = 4000, _maxBody = 40000;

const _kinds = {'course', 'book', 'certification', 'degree', 'project', 'practice'};

/// Reads a plan from a file or a pasted AI reply. Tolerates what chat apps
/// add around the JSON (prose, ``` fences) and trailing commas. Throws a
/// [FormatException] with a message fit for the learner.
CurriculumPlan parseCurriculum(String text) {
  final t = text.replaceFirst('﻿', '');
  final start = t.indexOf('{'), end = t.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw const FormatException('No plan found. Paste the whole reply, starting with { and ending with }.');
  }
  final body = t.substring(start, end + 1);
  Object? j;
  try {
    j = jsonDecode(body);
  } on FormatException {
    try {
      j = jsonDecode(body.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!));
    } on FormatException {
      throw const FormatException(
        'The plan is cut off or not valid JSON. If the reply was long, ask the AI to send it in parts.',
      );
    }
  }
  if (j is! Map) throw const FormatException('This is not a Vidya plan.');
  final format = j['format'];
  if (format != null && format != curriculumFormat) {
    throw FormatException(
      format == 'vidya-decks' ? 'This is a card file: import it on Review.' : 'This is not a Vidya plan.',
    );
  }
  final version = j['version'];
  if (version is num && version > 1) {
    throw const FormatException('This plan was made for a newer Vidya. Update Vidya and try again.');
  }

  final program = j['program'] is Map ? j['program'] as Map : j;
  final title = _str(program['title'], _maxTitle);
  if (title.isEmpty) throw const FormatException('The plan needs a program title.');
  final target = _str(program['targetDate'], 10);

  final courses = <PlanCourse>[];
  final seen = <String>{};
  for (final c in _list(j['courses'], _maxCourses, 'courses')) {
    if (c is! Map) continue;
    final name = _str(c['title'], _maxTitle);
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    final topics = <PlanTopic>[];
    for (final tp in _list(c['topics'], _maxTopics, 'topics in “$name”')) {
      final topic = tp is Map ? tp : {'title': tp};
      final tt = _str(topic['title'], _maxTitle);
      if (tt.isEmpty) continue;
      topics.add(
        PlanTopic(
          tt,
          minutes: _int(topic['minutes'], 30, 5, 600),
          details: _str(topic['details'], _maxText),
          resources: [
            for (final r in topic['resources'] is List ? topic['resources'] as List : const [])
              if (_resource(r) case final s when s.isNotEmpty) s,
          ],
        ),
      );
    }
    final kind = _str(c['kind'], 20).toLowerCase();
    final start = c['startWeek'] is num ? _int(c['startWeek'], 0, 0, 520) : null;
    final due = c['dueWeek'] is num ? _int(c['dueWeek'], 0, 0, 520) : null;
    final minutes = topics.fold(0, (a, t) => a + t.minutes);
    courses.add(
      PlanCourse(
        name,
        kind: _kinds.contains(kind) ? kind : 'course',
        hours: _int(c['hours'], (minutes / 60).round(), 0, 5000),
        provider: _str(c['provider'], _maxTitle),
        url: _str(c['url'], 500),
        startWeek: start,
        dueWeek: due == null || start == null || due >= start ? due : start,
        summary: _str(c['summary'], _maxText),
        topics: topics,
      ),
    );
  }

  final skills = <PlanSkill>[
    for (final s in _list(j['skills'], _maxSkills, 'skills'))
      if ((s is Map ? _str(s['name'], _maxTitle) : _str(s, _maxTitle)) case final name when name.isNotEmpty)
        (
          name: name,
          category: s is Map && _str(s['category'], 60).isNotEmpty ? _str(s['category'], 60) : 'General',
          target: s is Map ? _int(s['target'], 3, 1, 5) : 3,
        ),
  ];

  final cards = <PlanCard>[];
  for (final c in _list(j['cards'], _maxCards, 'cards')) {
    if (c is! Map) continue;
    final front = _str(c['front'], _maxText), back = _str(c['back'], _maxText);
    if (front.isEmpty || (back.isEmpty && !isCloze(front))) continue;
    final course = _str(c['course'], _maxTitle);
    final deck = _str(c['deck'], _maxTitle);
    cards.add((
      deck: deck.isNotEmpty ? deck : (course.isNotEmpty ? course : title),
      course: course,
      front: front,
      back: back,
    ));
  }

  final notes = <PlanNote>[
    for (final n in _list(j['notes'], _maxNotes, 'notes'))
      if (n is Map && _str(n['title'], _maxTitle).isNotEmpty)
        (
          title: _str(n['title'], _maxTitle),
          body: _str(n['body'], _maxBody),
          tags: n['tags'] is List
              ? [for (final x in n['tags'] as List) _str(x, 40).replaceAll(',', ' ')]
                    .where((x) => x.isNotEmpty)
                    .join(', ')
              : _str(n['tags'], 200),
        ),
  ];

  if (courses.isEmpty && cards.isEmpty && notes.isEmpty) {
    throw const FormatException('The plan has no courses, cards or notes.');
  }
  return CurriculumPlan(
    title: title,
    goal: _str(program['goal'], _maxText),
    targetDate: isValidIsoDate(target) ? target : null,
    part: _str(j['part'], 40),
    courses: courses,
    skills: skills,
    cards: cards,
    notes: notes,
  );
}

String _str(Object? v, int max) {
  if (v is! String && v is! num) return '';
  final s = '$v'.trim();
  return s.length > max ? s.substring(0, max) : s;
}

int _int(Object? v, int fallback, int min, int max) =>
    (v is num ? v.round() : int.tryParse('${v ?? ''}') ?? fallback).clamp(min, max);

List<Object?> _list(Object? v, int max, String what) {
  if (v is! List) return const [];
  if (v.length > max) throw FormatException('Too many $what (${v.length}); the most is $max.');
  return v;
}

/// "Title — https://…", a title or an address on its own.
String _resource(Object? r) {
  if (r is Map) {
    final t = _str(r['title'], _maxTitle), u = _str(r['url'], 500);
    return [t, u].where((x) => x.isNotEmpty).join(' — ');
  }
  return _str(r, 600);
}

/// A course's topic details and resources as a Markdown note, so nothing
/// the plan carries is lost (topics themselves hold only a title and time).
String courseGuideMarkdown(PlanCourse c, {String? due}) {
  final out = StringBuffer('# ${c.title}\n');
  final facts = [
    if (c.startWeek != null && c.dueWeek != null) 'Weeks ${c.startWeek}–${c.dueWeek}',
    if (due != null) 'due ${niceDate(due)}',
    if (c.hours > 0) 'about ${c.hours} h',
  ];
  if (facts.isNotEmpty) out.write('\n${facts.join(' · ')}\n');
  if (c.summary.isNotEmpty) out.write('\n${c.summary}\n');
  for (final (i, t) in c.topics.indexed) {
    out.write('\n## ${i + 1}. ${t.title} (${t.minutes} min)\n');
    if (t.details.isNotEmpty) out.write('\n${t.details}\n');
    if (t.resources.isNotEmpty) {
      out.write('\n');
      for (final r in t.resources) {
        out.write('- $r\n');
      }
    }
  }
  return out.toString();
}

/// What the learner copies into an AI chat. The reply is a plan Vidya can
/// import. Brackets are for the learner to fill in.
const curriculumPrompt = '''
You are an expert teacher and exam coach. Build me a complete study plan that I will import into Vidya, a learning app. Reply with ONE JSON object only — no other text before or after it.

ABOUT ME (I have filled these in):
- Goal, exam or qualification: [for example: Pass NYC Transit exam 7612, Car Inspector]
- Official syllabus, exam notice, book contents or other source material: [paste it here, or write "use what you know"]
- Where I am now: [beginner / some experience / experienced, and in what]
- Time I can study each week: [hours]
- Deadline or exam date: [yyyy-mm-dd, or "none"]
- Anything else: [preferred resources, weak areas, language]

WHAT TO MAKE:
1. A roadmap. Split the goal into courses (modules) in the order I should study them. Give each a startWeek and dueWeek, counted in whole weeks from today (week 0), so the whole plan fits my weekly hours before the deadline and leaves the last weeks for revision and practice tests.
2. Topics. For every course, list the topics to cover in order. Each topic has minutes of study, details (the key facts, formulas, procedures and common mistakes, 2–6 sentences), and resources (real, well-known, preferably free; if you are not sure of a web address, give only the title — never invent links).
3. Skills the plan builds, each with a category and a target level from 1 (aware) to 5 (expert).
4. Flashcards: 10–30 per course, testing the facts and principles in its topics. Write them in your own words; never copy questions from copyrighted books or past papers. Cloze cards are allowed: put {{c1::hidden words}} in the front and leave back empty.
5. Notes: one titled "Roadmap" with a week-by-week plan in Markdown; for an exam, one titled "Exam day" (format, timing, pass mark, what to bring, rules); add any others that help.

FORMAT (follow it exactly; leave out any optional field you have nothing for):
{
  "format": "vidya-curriculum",
  "version": 1,
  "part": "1 of 1",
  "program": {
    "title": "Short name of the goal",
    "goal": "One or two sentences: what I will be able to do",
    "targetDate": "yyyy-mm-dd"
  },
  "courses": [
    {
      "title": "Unique course title",
      "kind": "course",
      "hours": 12,
      "provider": "Optional: book, publisher or website",
      "url": "Optional: https://…",
      "startWeek": 0,
      "dueWeek": 2,
      "summary": "Why this course matters and what it covers",
      "topics": [
        {
          "title": "Topic title",
          "minutes": 45,
          "details": "Key points to learn",
          "resources": [{ "title": "Resource name", "url": "https://…" }]
        }
      ]
    }
  ],
  "skills": [{ "name": "Skill", "category": "Area", "target": 4 }],
  "cards": [{ "course": "Unique course title", "front": "Question", "back": "Answer" }],
  "notes": [{ "title": "Roadmap", "body": "Markdown text", "tags": ["plan"] }]
}

RULES:
- "kind" is one of: course, book, certification, degree, project, practice.
- Plain JSON: double quotes, no comments, no trailing commas, \\n for line breaks inside text.
- Every card's "course" must match a course title exactly.
- Be accurate. Leave out anything you are not sure of rather than guess.
- If everything will not fit in one reply, split it into parts. Set "part" to "1 of N", "2 of N" and so on. Every part repeats the same "program" block; part 1 also carries the skills and notes; each part holds whole courses with their own cards. I will say "next part" to get the next one.
''';
