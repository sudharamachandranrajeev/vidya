import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'achievements.dart';
import 'curriculum.dart';
import 'import.dart';
import 'review.dart';
import 'stats.dart';
import 'templates.dart';

const courseKinds = {
  'course': 'Course',
  'book': 'Book',
  'certification': 'Certification',
  'degree': 'Degree',
  'project': 'Project',
  'practice': 'Practice',
};

const portfolioKinds = {
  'project': 'Project',
  'certificate': 'Certificate',
  'publication': 'Publication',
  'talk': 'Talk',
  'contribution': 'Contribution',
  'degree': 'Degree',
};

const skillLevels = ['None', 'Aware', 'Learning', 'Competent', 'Proficient', 'Expert'];

/// What importing a study plan added (things already there are not counted).
typedef CurriculumImport = ({String programId, int courses, int topics, int skills, int cards, int notes});

/// Vidya's write path and the reads screens share.
class LearningBook {
  LearningBook(this.store);
  final Store store;

  AppDatabase get db => store.db as AppDatabase;

  Future<void> save<T extends Table, D>(TableInfo<T, D> table, Insertable<D> row, String id) =>
      store.save(table, row, id);

  Future<void> remove(TableInfo table, String id) => store.remove(table, id);

  // ---- curriculum ----

  Future<String> addProgram(String title, String goal, {required String today, String? target}) async {
    final id = newId();
    await save(
      db.learnPrograms,
      LearnProgramsCompanion.insert(
        id: id,
        title: title,
        goal: Value(goal),
        started: today,
        target: Value(target),
      ),
      id,
    );
    return id;
  }

  Future<String> addCourse(
    String title, {
    required String today,
    String? programId,
    String kind = 'course',
    String provider = '',
    String url = '',
    int hours = 0,
    String? due,
  }) async {
    final id = newId();
    await save(
      db.learnCourses,
      LearnCoursesCompanion.insert(
        id: id,
        programId: Value(programId),
        title: title,
        provider: Value(provider),
        url: Value(url),
        kind: Value(kind),
        hours: Value(hours),
        due: Value(due),
        added: today,
      ),
      id,
    );
    return id;
  }

  Future<void> addTopic(String courseId, String title, {int minutes = 30}) async {
    final last =
        await (db.select(db.learnTopics)
              ..where((t) => t.courseId.equals(courseId) & t.deleted.not())
              ..orderBy([(t) => OrderingTerm.desc(t.ord)])
              ..limit(1))
            .getSingleOrNull();
    final id = newId();
    await save(
      db.learnTopics,
      LearnTopicsCompanion.insert(
        id: id,
        courseId: courseId,
        title: title,
        minutes: Value(minutes),
        ord: Value((last?.ord ?? -1) + 1),
      ),
      id,
    );
  }

  /// Marks a topic done today (or open again) and moves its course on: a
  /// planned course starts, and one whose topics are all done finishes.
  Future<void> setTopicDone(Topic t, bool done, {required String today}) => db.transaction(() async {
    await save(db.learnTopics, t.copyWith(done: Value(done ? today : null)), t.id);
    final course = await (db.select(
      db.learnCourses,
    )..where((c) => c.id.equals(t.courseId))).getSingleOrNull();
    if (course == null || course.deleted) return;
    final topics = await (db.select(
      db.learnTopics,
    )..where((x) => x.courseId.equals(t.courseId) & x.deleted.not())).get();
    final all = topics.every((x) => x.id == t.id ? done : x.done != null);
    if (done && all) {
      await setCourseStatus(course, 'done', today: today);
    } else if (done && course.status == 'planned') {
      await setCourseStatus(course, 'doing', today: today);
    } else if (!done && course.status == 'done') {
      await setCourseStatus(course, 'doing', today: today);
    }
  });

  Future<void> setCourseStatus(Course c, String status, {required String today}) async {
    await save(
      db.learnCourses,
      c.copyWith(status: status, finished: Value(status == 'done' ? today : null)),
      c.id,
    );
    final pid = c.programId;
    if (pid == null) return;
    final program = await (db.select(db.learnPrograms)..where((p) => p.id.equals(pid))).getSingleOrNull();
    if (program == null || program.deleted) return;
    final courses = await (db.select(
      db.learnCourses,
    )..where((x) => x.programId.equals(pid) & x.deleted.not() & x.status.equals('dropped').not())).get();
    final finished =
        courses.isNotEmpty && courses.every((x) => x.id == c.id ? status == 'done' : x.status == 'done');
    if (finished && program.status != 'done') {
      await save(db.learnPrograms, program.copyWith(status: 'done'), pid);
    } else if (!finished && program.status == 'done') {
      await save(db.learnPrograms, program.copyWith(status: 'active'), pid);
    }
  }

  /// Deletes a program with its courses, their topics and sessions' links.
  Future<void> removeProgram(String id) => db.transaction(() async {
    final courses = await (db.select(db.learnCourses)..where((c) => c.programId.equals(id))).get();
    for (final c in courses) {
      await removeCourse(c.id);
    }
    await remove(db.learnPrograms, id);
  });

  Future<void> removeCourse(String id) => db.transaction(() async {
    final topics = await (db.select(db.learnTopics)..where((t) => t.courseId.equals(id))).get();
    for (final t in topics) {
      if (!t.deleted) await remove(db.learnTopics, t.id);
    }
    await remove(db.learnCourses, id);
  });

  /// Copies a starter curriculum: the program, its courses and topics, and
  /// the skills it builds (skills you already track are left alone).
  Future<String> importTemplate(ProgramTemplate t, {required String today}) => db.transaction(() async {
    final pid = await addProgram(t.title, t.goal, today: today);
    for (final c in t.courses) {
      final cid = await addCourse(c.title, today: today, programId: pid, kind: c.kind, hours: c.hours);
      for (final topic in c.topics) {
        await addTopic(cid, topic, minutes: (c.hours * 60 / c.topics.length).round().clamp(15, 240));
      }
    }
    final have = (await (db.select(
      db.learnSkills,
    )..where((s) => s.deleted.not())).get()).map((s) => s.name.toLowerCase()).toSet();
    for (final s in t.skills) {
      if (have.add(s.toLowerCase())) await addSkill(s, today: today);
    }
    return pid;
  });

  // ---- practice ----

  Future<void> logSession(
    int minutes, {
    required String today,
    String? courseId,
    String note = '',
    String? day,
  }) {
    final id = newId();
    return save(
      db.learnSessions,
      LearnSessionsCompanion.insert(
        id: id,
        courseId: Value(courseId),
        day: day ?? today,
        minutes: minutes,
        note: Value(note),
      ),
      id,
    );
  }

  Future<void> addAssessment(
    String title,
    double score,
    double max, {
    required String today,
    String? courseId,
  }) {
    final id = newId();
    return save(
      db.learnAssessments,
      LearnAssessmentsCompanion.insert(
        id: id,
        courseId: Value(courseId),
        title: title,
        day: today,
        score: score,
        max: Value(max),
      ),
      id,
    );
  }

  // ---- skills, portfolio, notes ----

  Future<void> addSkill(
    String name, {
    required String today,
    String category = 'General',
    int level = 0,
    int target = 3,
  }) {
    final id = newId();
    return save(
      db.learnSkills,
      LearnSkillsCompanion.insert(
        id: id,
        name: name,
        category: Value(category),
        level: Value(level),
        target: Value(target),
        updated: today,
      ),
      id,
    );
  }

  Future<void> setSkillLevel(Skill s, int level, {required String today}) =>
      save(db.learnSkills, s.copyWith(level: level, updated: today), s.id);

  Future<void> addPortfolio(
    String title, {
    required String today,
    String kind = 'project',
    String url = '',
    String skills = '',
    String summary = '',
  }) {
    final id = newId();
    return save(
      db.learnPortfolio,
      LearnPortfolioCompanion.insert(
        id: id,
        title: title,
        kind: Value(kind),
        url: Value(url),
        day: today,
        skills: Value(skills),
        summary: Value(summary),
      ),
      id,
    );
  }

  Future<void> saveNote(String title, String body, String tags, {required String today, Note? existing}) {
    final id = existing?.id ?? newId();
    return save(
      db.learnNotes,
      LearnNotesCompanion.insert(
        id: id,
        title: title,
        body: Value(body),
        tags: Value(tags),
        created: existing?.created ?? today,
        updated: today,
      ),
      id,
    );
  }

  // ---- flashcards ----

  /// Adds a card, or changes the text of [existing] without touching its
  /// schedule. A new card is due today.
  Future<void> saveCard(
    String front,
    String back, {
    required String today,
    String deck = 'General',
    String? courseId,
    String image = '',
    String audio = '',
    Flashcard? existing,
  }) {
    final id = existing?.id ?? newId();
    if (existing != null) {
      return save(
        db.learnCards,
        existing.copyWith(
          front: front,
          back: back,
          deck: deck,
          courseId: Value(courseId),
          image: image,
          audio: audio,
        ),
        id,
      );
    }
    return save(
      db.learnCards,
      LearnCardsCompanion.insert(
        id: id,
        front: front,
        back: back,
        deck: Value(deck),
        courseId: Value(courseId),
        image: Value(image),
        audio: Value(audio),
        due: today,
        created: today,
      ),
      id,
    );
  }

  /// Adds imported cards as new cards due today, leaving out any whose deck
  /// and front already exist (so importing a file twice changes nothing).
  /// Returns how many were added.
  Future<int> importCards(List<ImportedCard> cards, {required String today}) =>
      db.transaction(() => _addNewCards([for (final c in cards) (card: c, courseId: null)], today));

  Future<int> _addNewCards(List<({ImportedCard card, String? courseId})> cards, String today) async {
    final seen = {
      for (final c in await (db.select(db.learnCards)..where((r) => r.deleted.not())).get())
        '${c.deck}\u0000${c.front}',
    };
    var added = 0;
    for (final (:card, :courseId) in cards) {
      if (!seen.add('${card.deck}\u0000${card.front}')) continue;
      await saveCard(
        card.front,
        card.back,
        today: today,
        deck: card.deck,
        courseId: courseId,
        image: card.image,
        audio: card.audio,
      );
      added++;
    }
    return added;
  }

  /// Adds a study plan (see curriculum.dart). Everything merges by title, so
  /// importing a plan twice, or its parts one after another, adds each thing
  /// once: the program, its courses, their topics, skills, notes, and cards
  /// (by deck and front). Course due dates count the plan's weeks from [today].
  /// Topic details and resources go into one study-guide note per course.
  Future<CurriculumImport> importCurriculum(CurriculumPlan plan, {required String today}) =>
      db.transaction(() async {
        final key = plan.title.toLowerCase();
        final program = (await (db.select(
          db.learnPrograms,
        )..where((p) => p.deleted.not())).get()).where((p) => p.title.toLowerCase() == key).firstOrNull;
        final String pid;
        if (program == null) {
          pid = await addProgram(plan.title, plan.goal, today: today, target: plan.targetDate);
        } else {
          pid = program.id;
          final goal = program.goal.isEmpty ? plan.goal : program.goal;
          final target = program.target ?? plan.targetDate;
          if (goal != program.goal || target != program.target) {
            await save(db.learnPrograms, program.copyWith(goal: goal, target: Value(target)), pid);
          }
        }

        final noteTitles = {
          for (final n in await (db.select(db.learnNotes)..where((n) => n.deleted.not())).get())
            n.title.toLowerCase(),
        };
        var notes = 0;
        final tag = plan.title.replaceAll(',', ' ');
        Future<void> note(String title, String body, String tags) async {
          if (!noteTitles.add(title.toLowerCase())) return;
          await saveNote(title, body, tags, today: today);
          notes++;
        }

        final courseIds = {
          for (final c in await (db.select(
            db.learnCourses,
          )..where((c) => c.programId.equals(pid) & c.deleted.not())).get())
            c.title.toLowerCase(): c.id,
        };
        var courses = 0, topics = 0;
        for (final c in plan.courses) {
          final due = c.dueWeek == null ? null : addDays(today, c.dueWeek! * 7);
          var cid = courseIds[c.title.toLowerCase()];
          if (cid == null) {
            cid = await addCourse(
              c.title,
              today: today,
              programId: pid,
              kind: c.kind,
              provider: c.provider,
              url: c.url,
              hours: c.hours,
              due: due,
            );
            courseIds[c.title.toLowerCase()] = cid;
            courses++;
          }
          final courseId = cid;
          final have = {
            for (final t in await (db.select(
              db.learnTopics,
            )..where((t) => t.courseId.equals(courseId) & t.deleted.not())).get())
              t.title.toLowerCase(),
          };
          for (final t in c.topics) {
            if (!have.add(t.title.toLowerCase())) continue;
            await addTopic(courseId, t.title, minutes: t.minutes);
            topics++;
          }
          if (c.hasGuide) {
            await note('${c.title} — study guide', courseGuideMarkdown(c, due: due), '$tag, study guide');
          }
        }

        for (final n in plan.notes) {
          final title = n.title.toLowerCase().contains(key) ? n.title : '${plan.title} — ${n.title}';
          await note(title, n.body, [tag, n.tags].where((x) => x.isNotEmpty).join(', '));
        }

        final haveSkills = (await (db.select(
          db.learnSkills,
        )..where((s) => s.deleted.not())).get()).map((s) => s.name.toLowerCase()).toSet();
        var skills = 0;
        for (final s in plan.skills) {
          if (!haveSkills.add(s.name.toLowerCase())) continue;
          await addSkill(s.name, today: today, category: s.category, target: s.target);
          skills++;
        }

        final cards = await _addNewCards([
          for (final c in plan.cards)
            (
              card: (front: c.front, back: c.back, deck: c.deck, image: '', audio: ''),
              courseId: courseIds[c.course.toLowerCase()],
            ),
        ], today);

        return (programId: pid, courses: courses, topics: topics, skills: skills, cards: cards, notes: notes);
      });

  /// Records a review and moves the card to its next due day.
  Future<void> reviewCard(
    Flashcard c,
    Grade g, {
    required String today,
    ReviewPace pace = ReviewPace.standard,
  }) => db.transaction(() async {
    final n = nextSchedule(c, g, today, pace: pace);
    await save(
      db.learnCards,
      c.copyWith(interval: n.interval, ease: n.ease, reps: n.reps, lapses: n.lapses, due: n.due),
      c.id,
    );
    final id = newId();
    await save(
      db.learnReviews,
      LearnReviewsCompanion.insert(id: id, cardId: c.id, day: today, grade: g.index),
      id,
    );
  });

  Future<void> removeCard(String id) => remove(db.learnCards, id);

  // ---- measures and achievements ----

  Future<Stats> stats(String today) async {
    final unlocks = await (db.select(db.learnUnlocks)..where((u) => u.deleted.not())).get();
    return Stats(
      today: today,
      programs: await (db.select(db.learnPrograms)..where((r) => r.deleted.not())).get(),
      courses: await (db.select(db.learnCourses)..where((r) => r.deleted.not())).get(),
      topics: await (db.select(db.learnTopics)..where((r) => r.deleted.not())).get(),
      sessions: await (db.select(db.learnSessions)..where((r) => r.deleted.not())).get(),
      assessments: await (db.select(db.learnAssessments)..where((r) => r.deleted.not())).get(),
      skills: await (db.select(db.learnSkills)..where((r) => r.deleted.not())).get(),
      portfolio: await (db.select(db.learnPortfolio)..where((r) => r.deleted.not())).get(),
      notes: await (db.select(db.learnNotes)..where((r) => r.deleted.not())).get(),
      cards: await (db.select(db.learnCards)..where((r) => r.deleted.not())).get(),
      reviews: await (db.select(db.learnReviews)..where((r) => r.deleted.not())).get(),
      unlocked: unlocks.length,
    );
  }

  /// Saves the achievements reached since last time and returns them, so
  /// the app can celebrate each once.
  Future<List<Achievement>> unlockNew(String today) async {
    final s = await stats(today);
    final have = {for (final u in await (db.select(db.learnUnlocks)).get()) u.id};
    final fresh = [
      for (final a in achievements)
        if (!have.contains(a.key) && a.value(s) >= a.target) a,
    ];
    for (final a in fresh) {
      await save(
        db.learnUnlocks,
        LearnUnlocksCompanion.insert(id: a.key, day: today, deleted: const Value(false)),
        a.key,
      );
    }
    return fresh;
  }
}
