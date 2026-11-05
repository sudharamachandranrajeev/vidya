import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageScaffold(
    title: 'Settings',
    children: [
      _StreaksCard(),
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
