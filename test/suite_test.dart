import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/app/session.dart';
import 'package:vidya/domain/book.dart';
import 'package:vidya/suite.dart';

import 'support.dart';

void main() {
  testWidgets("the suite card shows today's study with only the suite overrides", (tester) async {
    late AppSession session;
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vidyaIdentity), store, LearningBook(store));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreSessionProvider.overrideWithValue(session),
          appIdentityProvider.overrideWithValue(vidyaSuite.identity),
          ...vidyaSuite.overrides(session),
        ],
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: vidyaSuite.theme(ref, Brightness.light),
            home: Scaffold(body: Builder(builder: vidyaSuite.summary)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('day streak'), findsNothing);
    expect(find.text('0 min'), findsOneWidget);
    expect(find.textContaining('Add a course'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => session.db.close());
  });
}
