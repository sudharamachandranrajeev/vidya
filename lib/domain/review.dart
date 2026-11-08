import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';

/// How well a card was remembered.
enum Grade {
  again('Again'),
  hard('Hard'),
  good('Good'),
  easy('Easy');

  const Grade(this.label);
  final String label;
}

/// A card's schedule after one review.
typedef Schedule = ({int interval, double ease, int reps, int lapses, String due});

/// How hard the schedule works: one named choice instead of raw ease and
/// interval settings. It stretches or shrinks every gap after a remembered
/// card; a forgotten card comes back the same day whatever the pace.
enum ReviewPace {
  light(
    'Light',
    'Longer gaps, fewer reviews a day. For keeping up with little time; you will forget a little more.',
    1.4,
  ),
  standard('Standard', 'The usual spacing: each card returns just before you would forget it.', 1),
  intensive(
    'Intensive',
    'Shorter gaps, more reviews a day. Before an exam, or for things you must not forget.',
    0.7,
  );

  const ReviewPace(this.label, this.about, this.factor);
  final String label, about;
  final double factor;

  static ReviewPace named(String? name) => values.firstWhere((p) => p.name == name, orElse: () => standard);
}

/// A day-granular take on SM-2. A forgotten card comes back today and
/// starts again; a remembered one waits longer each time, by its ease,
/// scaled by the [pace].
Schedule nextSchedule(Flashcard c, Grade g, String today, {ReviewPace pace = ReviewPace.standard}) {
  final s = _sm2(c, g);
  final interval = s.interval == 0 ? 0 : math.max(1, (s.interval * pace.factor).round());
  return (interval: interval, ease: s.ease, reps: s.reps, lapses: s.lapses, due: addDays(today, interval));
}

/// Why [c] is due when it is, in plain words.
String dueReason(Flashcard c, String today) {
  final behind = c.due.compareTo(today) < 0 ? daysBetween(c.due, today) : 0;
  final overdue = behind == 0
      ? ''
      : ' It has waited $behind ${behind == 1 ? 'day' : 'days'} past that, which is fine: review it now.';
  if (c.reps == 0 && c.lapses == 0) {
    return 'A new card. New cards are due from the day they are added.$overdue';
  }
  if (c.reps == 0) {
    return 'You marked it Again last time, so it comes back the same day until you remember it '
        '(forgotten ${c.lapses} ${c.lapses == 1 ? 'time' : 'times'} so far).$overdue';
  }
  final gap = c.interval == 1 ? '1 day' : '${c.interval} days';
  return 'You have remembered it ${c.reps} ${c.reps == 1 ? 'time' : 'times'} in a row, so it waited $gap '
      'before coming back on ${niceDate(c.due)}. Each Good makes the next gap about '
      '${c.ease.toStringAsFixed(1)} times longer; Hard and Again shorten it.$overdue';
}

({int interval, double ease, int reps, int lapses}) _sm2(Flashcard c, Grade g) {
  var ease = c.ease, reps = c.reps, lapses = c.lapses;
  final int interval;
  switch (g) {
    case Grade.again:
      ease -= 0.2;
      reps = 0;
      lapses++;
      interval = 0;
    case Grade.hard:
      ease -= 0.15;
      interval = c.reps == 0 ? 1 : math.max(c.interval + 1, (c.interval * 1.2).round());
      reps++;
    case Grade.good:
      interval = _grown(c);
      reps++;
    case Grade.easy:
      ease += 0.15;
      interval = math.max(_grown(c) + 1, (_grown(c) * 1.3).round());
      reps++;
  }
  return (interval: interval, ease: ease.clamp(1.3, 3.0), reps: reps, lapses: lapses);
}

int _grown(Flashcard c) => switch (c.reps) {
  0 => 1,
  1 => 3,
  _ => math.max(c.interval + 1, (c.interval * c.ease).round()),
};

/// Cards with an interval this long are "mature": held in long-term memory.
const matureDays = 21;
