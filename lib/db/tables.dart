import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Table names are unique across the Brahma suite: every app on an account
// reads the same change log and applies only its own tables. Vidya's all
// start with `learn_`. Dates are yyyy-MM-dd.

/// A curriculum: a goal made of courses (ERPNext's Program).
@DataClassName('Program')
class LearnPrograms extends Table with SyncedRow {
  TextColumn get title => text()();
  TextColumn get goal => text().withDefault(const Constant(''))();

  /// active | paused | done
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get started => text()();
  TextColumn get target => text().nullable()();
}

/// One course, book, certification or project inside a program.
@DataClassName('Course')
class LearnCourses extends Table with SyncedRow {
  TextColumn get programId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get provider => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();

  /// course | book | certification | degree | project | practice
  TextColumn get kind => text().withDefault(const Constant('course'))();

  /// planned | doing | done | dropped
  TextColumn get status => text().withDefault(const Constant('planned'))();

  /// Estimated hours to finish.
  IntColumn get hours => integer().withDefault(const Constant(0))();
  TextColumn get due => text().nullable()();
  TextColumn get finished => text().nullable()();
  TextColumn get added => text()();
}

/// A lesson or task inside a course (ERPNext's Topic).
@DataClassName('Topic')
class LearnTopics extends Table with SyncedRow {
  TextColumn get courseId => text()();
  TextColumn get title => text()();

  /// Estimated minutes.
  IntColumn get minutes => integer().withDefault(const Constant(30))();
  IntColumn get ord => integer().withDefault(const Constant(0))();

  /// The day it was finished, null while open.
  TextColumn get done => text().nullable()();
}

/// Time spent studying.
@DataClassName('StudySession')
class LearnSessions extends Table with SyncedRow {
  TextColumn get courseId => text().nullable()();
  TextColumn get day => text()();
  IntColumn get minutes => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// A quiz, exam or self-test result.
@DataClassName('Assessment')
class LearnAssessments extends Table with SyncedRow {
  TextColumn get courseId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get day => text()();
  RealColumn get score => real()();
  RealColumn get max => real().withDefault(const Constant(100))();
}

/// A skill and how far it has come against where it should be.
@DataClassName('Skill')
class LearnSkills extends Table with SyncedRow {
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('General'))();

  /// 0 (none) to 5 (expert).
  IntColumn get level => integer().withDefault(const Constant(0))();
  IntColumn get target => integer().withDefault(const Constant(3))();
  TextColumn get updated => text()();
}

/// Evidence for the candidate's portfolio.
@DataClassName('PortfolioItem')
class LearnPortfolio extends Table with SyncedRow {
  TextColumn get title => text()();

  /// project | certificate | publication | talk | contribution | degree
  TextColumn get kind => text().withDefault(const Constant('project'))();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get day => text()();

  /// Comma-separated skill names it shows.
  TextColumn get skills => text().withDefault(const Constant(''))();
  TextColumn get summary => text().withDefault(const Constant(''))();
}

/// Knowledge notes.
@DataClassName('Note')
class LearnNotes extends Table with SyncedRow {
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// Comma-separated.
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get created => text()();
  TextColumn get updated => text()();
}

/// A flashcard, reviewed on a spaced-repetition schedule (see review.dart).
@DataClassName('Flashcard')
class LearnCards extends Table with SyncedRow {
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get deck => text().withDefault(const Constant('General'))();
  TextColumn get courseId => text().nullable()();

  /// Optional media, each a web address or a file path on this device. A
  /// cloze card hides `{{c1::answer}}` spans in [front] instead of using [back].
  TextColumn get image => text().withDefault(const Constant(''))();
  TextColumn get audio => text().withDefault(const Constant(''))();

  /// The day it is next shown.
  TextColumn get due => text()();

  /// Days between the last review and [due]; 0 while new or relearning.
  IntColumn get interval => integer().withDefault(const Constant(0))();
  RealColumn get ease => real().withDefault(const Constant(2.5))();

  /// Recalls in a row since it was last forgotten.
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  TextColumn get created => text()();
}

/// One review of a flashcard.
@DataClassName('CardReview')
class LearnReviews extends Table with SyncedRow {
  TextColumn get cardId => text()();
  TextColumn get day => text()();

  /// 0 again, 1 hard, 2 good, 3 easy.
  IntColumn get grade => integer()();
}

/// An achievement earned; the row id is the achievement's key.
@DataClassName('Unlock')
class LearnUnlocks extends Table with SyncedRow {
  TextColumn get day => text()();
}

@DataClassName('Pref')
class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
