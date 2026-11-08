import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidya/app/app.dart';
import 'package:vidya/app/modules.dart';
import 'package:vidya/app/providers.dart';

import 'app_harness.dart';
import 'seed.dart';

/// Smoke tests: every page builds, with and without data, on phone and
/// desktop widths, without throwing or overflowing; and the main flows.
void main() {
  final pages = [for (final d in allDestinations) d.label];

  testWidgets('every page builds on a desktop window, empty and with data', (tester) async {
    for (final seeded in [false, true]) {
      final app = AppHarness(tester)..desktop();
      await app.open(seed: seeded ? seedBook : null);
      await app.run();
      for (final label in pages) {
        await app.go(label);
        expect(tester.takeException(), isNull, reason: '$label (seeded: $seeded)');
      }
      await app.close();
    }
  });

  testWidgets('every page builds on a phone', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run();
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('starting from a template, finishing a topic earns an achievement', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Learn');
    await app.tapText('Use a template');
    await app.tapText('Software engineer');
    expect(find.text('Software engineer'), findsOneWidget);
    await app.tapText('Software engineer');
    await app.tapText('Programming fundamentals');
    await app.tap(find.byType(Checkbox).first);
    expect(find.textContaining('Achievement earned: First step'), findsOneWidget);
    await app.close();
  });

  testWidgets('a pasted AI reply previews and imports as a program', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Learn');
    await app.tapText('Import a plan');
    expect(find.text('Copy AI prompt'), findsOneWidget);
    await app.enter('AI reply', 'not a plan');
    expect(find.textContaining('No plan found'), findsOneWidget);
    await app.enter(
      'AI reply',
      'Here you go:\n```json\n{"format": "vidya-curriculum", "version": 1, '
          '"program": {"title": "Pottery", "goal": "Throw a bowl"}, '
          '"courses": [{"title": "Wheel basics", "dueWeek": 2, "topics": [{"title": "Centering", "details": "Brace your arms."}]}], '
          '"cards": [{"course": "Wheel basics", "front": "First step on the wheel?", "back": "Centering"}]}\n```',
    );
    expect(find.text('1 courses · 1 topics · 1 cards · 0 skills · 0 notes'), findsOneWidget);
    await app.tapText('Import');
    expect(find.text('Pottery'), findsOneWidget);
    expect(find.text('0 of 1 courses'), findsOneWidget);
    // The topic's details became a study-guide note.
    expect(find.textContaining('Achievement earned: First note'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a new card is reviewed and the queue clears', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Review');
    await app.tapText('Card');
    await app.enter('Front: the question', 'Capital of Japan?');
    await app.enter('Back: the answer', 'Tokyo');
    await app.tapText('Save');
    expect(find.text('1 card due'), findsOneWidget);
    await app.tapText('Begin review');
    await app.tapText('Show answer');
    expect(find.text('Tokyo'), findsOneWidget);
    await app.tapText('Good');
    expect(find.text('All clear.'), findsOneWidget);
    expect(find.textContaining('Achievement earned: First recall'), findsOneWidget);
    await app.tapText('Done');
    expect(find.text('Nothing due'), findsOneWidget);
    await app.close();
  });

  testWidgets('the focus timer opens from Home and can be paused', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open();
    await app.run();
    await app.tap(find.byIcon(Icons.self_improvement).first);
    expect(find.text('25:00'), findsOneWidget);
    await app.tapText('15 min');
    expect(find.text('15:00'), findsOneWidget);
    await app.tapText('Begin');
    await app.tapText('Pause');
    expect(find.text('paused'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('streaks are hidden until switched on in Settings', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedBook);
    await app.run();
    await app.go('Home');
    expect(find.text('day streak'), findsNothing);
    await app.go('Progress');
    expect(find.text('Streak'), findsNothing);
    // What the Settings switch does.
    final scope = ProviderScope.containerOf(tester.element(find.byType(VidyaApp)));
    await tester.runAsync(() => scope.read(showStreaksProvider.notifier).set(true));
    await app.settle();
    await app.go('Home');
    expect(find.text('day streak'), findsOneWidget);
    await app.go('Progress');
    expect(find.text('Streak'), findsOneWidget);
    await app.close();
  });
}
