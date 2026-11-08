import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/zen.dart';
import 'modules.dart';
import 'providers.dart';
import 'reminders.dart';

class VidyaApp extends StatelessWidget {
  const VidyaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vidya',
    debugShowCheckedModeBanner: false,
    theme: vidyaTheme(Brightness.light),
    darkTheme: vidyaTheme(Brightness.dark),
    builder: (context, child) => AppLockGate(child: Backdrop(child: child ?? const SizedBox.shrink())),
    home: home,
  );
}

/// The app, opening the links the platform hands over (a scanned pairing
/// code).
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => const LinkHandler(child: VidyaHome());
}

/// Vidya's screens. There is no onboarding: Home says what to do first.
/// Each achievement a write earns is announced once, quietly. [onHome]
/// leads back to the Brahma suite's home screen when the suite hosts Vidya.
class VidyaHome extends ConsumerWidget {
  const VidyaHome({super.key, this.onHome});
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reminderSyncProvider);
    ref.listen(celebrationsProvider, (_, list) {
      if (list.isEmpty) return;
      final text = list.length == 1
          ? 'Achievement earned: ${list.first.title}'
          : 'Achievements earned: ${list.map((a) => a.title).join(', ')}';
      ref.read(celebrationsProvider.notifier).clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('🏅 $text')));
    });
    return AppShell(destinations: allDestinations, floating: true, onHome: onHome);
  }
}
