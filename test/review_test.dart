import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/db/database.dart';
import 'package:vidya/domain/book.dart';
import 'package:vidya/domain/cloze.dart';
import 'package:vidya/domain/export.dart';
import 'package:vidya/domain/import.dart';
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

    test('pace stretches or shrinks remembered gaps, never a forgotten card', () async {
      await book.saveCard('Q', 'A', today: today);
      final c = (await card()).copyWith(reps: 3, interval: 10, ease: 2.5);
      int gap(Grade g, ReviewPace p) => nextSchedule(c, g, today, pace: p).interval;
      expect(
        [for (final p in ReviewPace.values) gap(Grade.good, p)],
        [35, 25, 18], // 25 × 1.4, 25, 25 × 0.7
      );
      for (final p in ReviewPace.values) {
        expect(gap(Grade.again, p), 0);
        expect(gap(Grade.hard, p) <= gap(Grade.good, p) && gap(Grade.good, p) < gap(Grade.easy, p), isTrue);
      }
      // A new card's first gap is never shorter than a day.
      expect(nextSchedule(await card(), Grade.good, today, pace: ReviewPace.intensive).interval, 1);
      await book.reviewCard(await card(), Grade.good, today: today, pace: ReviewPace.light);
      expect((await card()).due, '2026-10-25');
      expect(ReviewPace.named('nonsense'), ReviewPace.standard);
    });

    test('dueReason explains new, forgotten, remembered and overdue cards', () async {
      await book.saveCard('Q', 'A', today: today);
      final c = await card();
      expect(dueReason(c, today), startsWith('A new card.'));
      expect(dueReason(c.copyWith(lapses: 2), today), contains('forgotten 2 times'));
      final known = c.copyWith(reps: 3, interval: 8, ease: 2.6, due: today);
      expect(dueReason(known, today), contains('remembered it 3 times in a row, so it waited 8 days'));
      expect(dueReason(known, today), contains('about 2.6 times longer'));
      expect(dueReason(known, today), isNot(contains('past that')));
      expect(dueReason(known, '2026-10-27'), contains('waited 3 days past that'));
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

  group('export', () {
    test('decksJson shares text, deck and media but no schedule', () async {
      await book.saveCard('B?', 'b', today: today, deck: 'Z', image: 'https://x/y.png');
      await book.saveCard('A?', 'a', today: today, deck: 'A');
      await book.reviewCard(
        await book.db.select(book.db.learnCards).get().then((l) => l.first),
        Grade.good,
        today: today,
      );
      final j = jsonDecode(decksJson((await book.stats(today)).cards)) as Map<String, dynamic>;
      expect((j['format'], j['version']), ('vidya-decks', 1));
      final cards = (j['cards'] as List).cast<Map<String, dynamic>>();
      expect(cards.map((c) => c['front']), ['A?', 'B?']);
      expect(cards[1]['image'], 'https://x/y.png');
      expect(cards[0].containsKey('image'), isFalse);
      expect(cards.expand((c) => c.keys).toSet(), {'deck', 'front', 'back', 'image'});
    });
  });

  group('import', () {
    List<int> b(String s) => utf8.encode(s);

    test('Quizlet tab export: term and definition, quoted multi-line fields', () {
      final r = parseDeckFile('q.txt', b('Hola\tHello\n"Adi\nos"\t"Good ""bye"""\n\nlonely\t\n'));
      expect(r.cards.map((c) => (c.front, c.back)), [('Hola', 'Hello'), ('Adi\nos', 'Good "bye"')]);
      expect((r.skipped, r.cards.first.deck), (1, 'Imported'));
    });

    test('CSV with header names columns, incl. deck, media and cloze without back', () {
      final r = parseDeckFile(
        'a.csv',
        b('﻿Question,Answer,Deck,Image\r\nQ1,A1,Bio,https://x/y.png\r\nCapital is {{c1::Paris}},,Geo,\r\n'),
      );
      expect(r.cards[0], (front: 'Q1', back: 'A1', deck: 'Bio', image: 'https://x/y.png', audio: ''));
      expect(r.cards[1].deck, 'Geo');
      expect(isCloze(r.cards[1].front), isTrue);
    });

    test('Anki plain-text export skips # lines; vidya json round-trips', () async {
      expect(parseDeckFile('n.txt', b('#separator:tab\n#html:false\nF\tB\ttag\n')).cards.single.back, 'B');
      await book.saveCard('J?', 'j', today: today, deck: 'D', audio: 'https://x/a.mp3');
      final r = parseDeckFile('d.json', b(decksJson((await book.stats(today)).cards)));
      expect(r.cards.single, (front: 'J?', back: 'j', deck: 'D', image: '', audio: 'https://x/a.mp3'));
    });

    test('.apkg and bad files give a clear message', () {
      expect(
        () => parseDeckFile('x.apkg', [80, 75]),
        throwsA(isA<FormatException>().having((e) => e.message, 'm', contains('not yet supported'))),
      );
      expect(() => parseDeckFile('x.csv', b('')), throwsFormatException);
      expect(() => parseDeckFile('x.json', b('{"a":1}')), throwsFormatException);
    });

    test('importCards adds new due cards once; a second import adds nothing', () async {
      final cards = parseDeckFile('a.csv', b('front,back\nQ,A\nQ2,A2\n')).cards;
      expect(await book.importCards(cards, today: today), 2);
      expect(await book.importCards(cards, today: today), 0);
      final all = await book.db.select(book.db.learnCards).get();
      expect(all.map((c) => (c.deck, c.due)).toSet(), {('Imported', today)});
    });
  });
}
