import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/app/providers.dart';
import 'package:vidya/app/reminders.dart';
import 'package:vidya/app/session.dart';
import 'package:vidya/domain/book.dart';
import 'package:vidya/domain/reminders.dart';

import 'support.dart';

class FakeScheduler implements ReminderScheduler {
  FakeScheduler({this.allow = true});
  final bool allow;
  List<(DateTime, int)>? scheduled;
  int asked = 0;

  @override
  bool get supported => true;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<(DateTime when, int due)> reminders) async => scheduled = reminders;
}

void main() {
  group('planReminders', () {
    test('only days with cards due get one, counting what is still waiting', () {
      expect(planReminders([0, 0, 2, 0, 1, 0, 0], perWeek: 7, todayOpen: true), [
        (day: 2, due: 2),
        (day: 3, due: 2),
        (day: 4, due: 3),
        (day: 5, due: 3),
        (day: 6, due: 3),
      ]);
    });

    test('never more than the weekly limit the learner chose', () {
      final plan = planReminders([5, 1, 1, 1, 1, 1, 1], perWeek: 2, todayOpen: true);
      expect(plan.map((r) => r.day), [0, 1]);
    });

    test('nothing due means no reminders', () {
      expect(planReminders([0, 0, 0, 0, 0, 0, 0], perWeek: 7, todayOpen: true), isEmpty);
    });

    test('today is skipped once its reminder time has passed, but its cards still count', () {
      final plan = planReminders([3, 0, 0, 0, 0, 0, 0], perWeek: 1, todayOpen: false);
      expect(plan, [(day: 1, due: 3)]);
    });
  });

  group('reminder settings and scheduling', () {
    late AppSession session;
    late FakeScheduler scheduler;
    late ProviderContainer container;

    Future<void> open({bool allow = true}) async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vidyaIdentity), store, LearningBook(store));
      scheduler = FakeScheduler(allow: allow);
      container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWithValue(session),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
    }

    tearDown(() async {
      container.dispose();
      await session.db.close();
    });

    test('off by default; the choices are kept on the device', () async {
      await open();
      var s = await container.read(remindersProvider.future);
      expect((s.enabled, s.hour, s.perWeek), (false, 18, 3));

      final n = container.read(remindersProvider.notifier);
      expect(await n.setEnabled(true), isTrue);
      await n.setHour(8);
      await n.setPerWeek(2);

      container.invalidate(remindersProvider);
      s = await container.read(remindersProvider.future);
      expect((s.enabled, s.hour, s.perWeek), (true, 8, 2));
    });

    test('refused notification permission leaves reminders off', () async {
      await open(allow: false);
      await container.read(remindersProvider.future);
      expect(await container.read(remindersProvider.notifier).setEnabled(false), isTrue);
      expect(await container.read(remindersProvider.notifier).setEnabled(true), isFalse);
      expect((await container.read(remindersProvider.future)).enabled, isFalse);
    });

    test('schedules at the chosen time only for days with due cards, within the limit', () async {
      await open();
      final now = DateTime.now();
      final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await session.book.saveCard('Q1', 'A1', today: day);
      await session.book.saveCard('Q2', 'A2', today: day);

      final n = container.read(remindersProvider.notifier);
      await container.read(remindersProvider.future);
      await n.setEnabled(true);
      await n.setHour(7);
      await n.setPerWeek(2);
      await container.read(reminderSyncProvider.future);

      final plan = scheduler.scheduled!;
      expect(plan, hasLength(2));
      for (final (at, due) in plan) {
        expect(at.hour, 7);
        expect(due, 2);
        expect(at.isAfter(now), isTrue);
      }

      await n.setEnabled(false);
      await container.read(reminderSyncProvider.future);
      expect(scheduler.scheduled, isEmpty);
    });
  });
}
