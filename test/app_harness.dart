import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/app/app.dart';
import 'package:vidya/app/providers.dart';
import 'package:vidya/app/session.dart';
import 'package:vidya/domain/book.dart';

import 'support.dart';

/// The whole app over a fresh in-memory database, for widget tests.
class AppHarness {
  AppHarness(this.tester);
  final WidgetTester tester;
  late AppSession session;

  LearningBook get book => session.book;

  /// Opens the database; [seed] runs before the app starts.
  Future<void> open({Future<void> Function(LearningBook book)? seed}) async {
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vidyaIdentity), store, LearningBook(store));
      // Past the first-run choice between this device only and sync.
      await session.db.setLocalSetting('onboarding.sync', 'done');
      await seed?.call(session.book);
    });
  }

  Future<void> run({List<Override> overrides = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...vidyaOverrides(session), ...overrides],
        retry: (_, _) => null,
        child: const VidyaApp(),
      ),
    );
    await settle();
  }

  Future<void> close() async {
    // Disposing the scope stops the sync and refresh timers.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  }

  /// Lets database work (real I/O) and animations finish.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle();
  }

  Future<void> tapText(String text) => tap(find.text(text).last);

  /// Types into the text field labelled [label].
  Future<void> enter(String label, String text) async {
    final f = find.widgetWithText(TextField, label).last;
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  /// Goes to a top-level page through the rail (desktop) or the bar and its
  /// More sheet (phone).
  Future<void> go(String page) async {
    final rail = find.descendant(of: find.byType(NavigationRail), matching: find.text(page));
    if (rail.evaluate().isNotEmpty) return tap(rail);
    // Phones: the dock holds every screen and scrolls to the one asked for.
    await tap(
      find.descendant(
        of: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Dock'),
        matching: find.byTooltip(page),
      ),
    );
  }

  void desktop() => _size(const Size(1400, 900));

  void phone() => _size(const Size(390, 844));

  void _size(Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
}
