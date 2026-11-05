import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/db/database.dart';
import 'package:vidya/domain/book.dart';
import 'package:vidya/domain/cloze.dart';
import 'package:vidya/domain/export.dart';
import 'package:vidya/domain/review.dart';
import 'package:vidya/domain/stats.dart';

import 'seed.dart';
import 'support.dart';

const today = '2026-10-24';

void main() {
  late LearningBook book;
  setUp(() async => book = LearningBook(await Store.open(memoryDatabase())));
  tearDown(() => book.db.close());

  Future<Flashcard> card() async => (await book.db.select(book.db.learnCards).get()).single;

  group('scheduling', () {
    test('a remembered card waits 1, then 3, then interval × ease days', () async {
      await book.saveCard('Q', 'A', today: today);
      var c = await card();
      expect(c.due, today);
      await book.reviewCard(c, Grade.good, today: today);
      c = await card();
      expect((c.interval, c.due, c.reps), (1, '2026-10-25', 1));
      await book.reviewCard(c, Grade.good, today: c.due);
      c = await card();
      expect((c.interval, c.due), (3, '2026-10-28'));
      await book.reviewCard(c, Grade.good, today: c.due);
      c = await card();
      expect(c.interval, (3 * 2.5).round());
    });

    test('forgetting brings it back today, lowers ease and counts a lapse', () async {
      await book.saveCard('Q', 'A', today: today);
      await book.reviewCard(await card(), Grade.good, today: today);
      await book.reviewCard(await card(), Grade.again, today: '2026-10-25');
      final c = await card();
      expect((c.interval, c.due, c.reps, c.lapses), (0, '2026-10-25', 0, 1));
      expect(c.ease, closeTo(2.3, 1e-9));
    });

    test('easy always waits longer than good, hard less; ease stays in bounds', () async {
      await book.saveCard('Q', 'A', today: today);
      final c = await card();
      final i = {for (final g in Grade.values) g: nextSchedule(c, g, today).interval};
      expect(i[Grade.hard]! <= i[Grade.good]!, isTrue);
      expect(i[Grade.easy]! > i[Grade.good]!, isTrue);
      var x = c;
      for (var n = 0; n < 20; n++) {
        final s = nextSchedule(x, Grade.again, today);
        x = x.copyWith(ease: s.ease, reps: s.reps, interval: s.interval, lapses: s.lapses);
      }
      expect(x.ease, 1.3);
    });

    test('editing a card keeps its schedule', () async {
      await book.saveCard('Q', 'A', today: today);
      await book.reviewCard(await card(), Grade.good, today: today);
      await book.saveCard('Q2', 'A2', today: today, deck: 'Words', existing: await card());
      final c = await card();
      expect((c.front, c.deck, c.due, c.reps), ('Q2', 'Words', '2026-10-25', 1));
    });
  });

  test('reviews feed experience, streak, retention, the quest and achievements', () async {
    await book.saveCard('Q', 'A', today: today);
    var s = await book.stats(today);
    expect(s.xp, Stats.xpNewCard);
    expect(s.quests.where((q) => q.id == 'review').single.done, isFalse);
    await book.reviewCard(await card(), Grade.good, today: today);
    s = await book.stats(today);
    expect(s.xp, Stats.xpNewCard + Stats.xpReview);
    expect(s.streak, 1);
    expect(s.retention, 1);
    expect(s.dueCards, isEmpty);
    expect(s.quests.where((q) => q.id == 'review').single.done, isTrue);
    expect((await book.unlockNew(today)).map((a) => a.key), contains('review-1'));
  });

  test('a long focus session earns Deep focus', () async {
    await book.logSession(50, today: today);
    expect((await book.unlockNew(today)).map((a) => a.key), contains('focus-50'));
  });

  test('portfolio Markdown lists skills, work and finished courses', () async {
    await seedBook(book);
    final md = portfolioMarkdown(await book.stats(today));
    expect(md, startsWith('# Portfolio\n'));
    expect(md, contains('## Skills'));
    expect(md, contains('### Habit tracker app'));
    expect(md, contains('Skills: Programming, Git'));
    expect(md, contains('hours of study'));
  });

  test('a version 1 database gains the flashcard tables and keeps its rows', () async {
    final dir = await Directory.systemTemp.createTemp('vidya');
    final file = File('${dir.path}/v1.db');
    var db = AppDatabase(NativeDatabase(file));
    await LearningBook(await Store.open(db)).logSession(30, today: today);
    // Turn it back into version 1: no flashcard tables.
    await db.customStatement('DROP TABLE learn_cards');
    await db.customStatement('DROP TABLE learn_reviews');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final upgraded = LearningBook(await Store.open(db));
    await upgraded.saveCard('Q', 'A', today: today);
    final s = await upgraded.stats(today);
    expect(s.sessions, hasLength(1));
    expect(s.cards, hasLength(1));
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a version 2 database gains card media columns and keeps its cards', () async {
    final dir = await Directory.systemTemp.createTemp('vidya');
    final file = File('${dir.path}/v2.db');
    var db = AppDatabase(NativeDatabase(file));
    await LearningBook(await Store.open(db)).saveCard('Q', 'A', today: today);
    await db.customStatement('ALTER TABLE learn_cards DROP COLUMN image');
    await db.customStatement('ALTER TABLE learn_cards DROP COLUMN audio');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final upgraded = LearningBook(await Store.open(db));
    final c = (await upgraded.stats(today)).cards.single;
    expect((c.front, c.image, c.audio), ('Q', '', ''));
    await db.close();
    await dir.delete(recursive: true);
  });

  group('media and cloze', () {
    test('image and audio are saved and edited with the card', () async {
      await book.saveCard('Q', 'A', today: today, image: 'https://x/y.png', audio: '/a.mp3');
      var c = await card();
      expect((c.image, c.audio), ('https://x/y.png', '/a.mp3'));
      await book.saveCard('Q', 'A', today: today, existing: c);
      c = await card();
      expect((c.image, c.audio), ('', ''));
    });

    test('cloze spans hide and reveal, with an optional hint', () {
      const f = 'The capital of {{c1::France::country}} is {{c2::Paris}}.';
      expect(isCloze(f), isTrue);
      expect(isCloze('plain'), isFalse);
      expect(clozeQuestion(f), 'The capital of [country] is […].');
      expect(clozeAnswer(f), 'The capital of France is Paris.');
      expect(clozeAnswers(f), ['France', 'Paris']);
    });
  });
}
