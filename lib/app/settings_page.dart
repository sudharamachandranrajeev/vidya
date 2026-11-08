import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/review.dart';
import 'providers.dart';
import 'reminders.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageScaffold(
    title: 'Settings',
    children: [
      _StreaksCard(),
      _PaceCard(),
      _RemindersCard(),
      AppLockCard(),
      HintsCard(),
      SyncCard(),
      SecurityCard(
        network:
            'Vidya makes no network requests of its own. It talks to your sync server only if you sign in.',
      ),
      AboutCard(
        description:
            'Learning and knowledge management: programs, courses, skills, portfolio, notes and progress.',
      ),
    ],
  );
}

/// Streaks are opt-in: off, no day count is shown anywhere. Achievements
/// are not affected.
class _StreaksCard extends ConsumerWidget {
  const _StreaksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Streaks',
    padding: const EdgeInsets.only(bottom: 8),
    child: SwitchListTile(
      title: const Text('Show day streaks'),
      subtitle: const Text(
        'Count days in a row on Home and Progress. Off by default; achievements stay either way.',
      ),
      value: ref.watch(showStreaksProvider).value ?? false,
      onChanged: (v) => ref.read(showStreaksProvider.notifier).set(v),
    ),
  );
}

/// Review pace: three named presets over the flashcard schedule, so nobody
/// has to tune ease factors or intervals.
class _PaceCard extends ConsumerWidget {
  const _PaceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pace = ref.watch(reviewPaceProvider).value ?? ReviewPace.standard;
    return SectionCard(
      title: 'Review pace',
      padding: const EdgeInsets.only(bottom: 8),
      child: RadioGroup<ReviewPace>(
        groupValue: pace,
        onChanged: (p) {
          if (p != null) ref.read(reviewPaceProvider.notifier).set(p);
        },
        child: Column(
          children: [
            for (final p in ReviewPace.values)
              RadioListTile<ReviewPace>(value: p, title: Text(p.label), subtitle: Text(p.about)),
          ],
        ),
      ),
    );
  }
}

/// Review reminders: on this device only, at a time and a weekly limit the
/// learner sets once. Each is tied to cards that are due.
class _RemindersCard extends ConsumerWidget {
  const _RemindersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(reminderSchedulerProvider).supported;
    final s = ref.watch(remindersProvider).value ?? const ReminderSettings();
    final notifier = ref.read(remindersProvider.notifier);
    return SectionCard(
      title: 'Reminders',
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Remind me to review'),
            subtitle: Text(
              supported
                  ? 'A notification from this device when cards are due. Nothing is sent from a server.'
                  : 'Available on Android.',
            ),
            value: supported && s.enabled,
            onChanged: supported
                ? (v) async {
                    final ok = await notifier.setEnabled(v);
                    if (!ok && context.mounted) {
                      showMessage(context, 'Allow notifications for Vidya in the device settings.');
                    }
                  }
                : null,
          ),
          if (supported && s.enabled) ...[
            ListTile(
              title: const Text('Time of day'),
              trailing: DropdownButton<int>(
                value: s.hour,
                onChanged: (h) => h == null ? null : notifier.setHour(h),
                items: [
                  for (var h = 0; h < 24; h++)
                    DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
                ],
              ),
            ),
            ListTile(
              title: const Text('At most per week'),
              subtitle: const Text('Reminders stop at this limit, even if cards stay due.'),
              trailing: DropdownButton<int>(
                value: s.perWeek,
                onChanged: (n) => n == null ? null : notifier.setPerWeek(n),
                items: [for (var n = 1; n <= 7; n++) DropdownMenuItem(value: n, child: Text('$n'))],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
