import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/answer.dart';
import '../domain/review.dart';
import '../domain/stats.dart';
import 'charts.dart';
import 'common.dart';
import 'zen.dart';

/// Flashcards: what is due, the decks, and the next week's load.
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
    title: 'Review',
    banner: 'page.review',
    fab: FloatingActionButton.extended(
      onPressed: () => cardDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Card'),
    ),
    body: AsyncView(
      ref.watch(statsProvider),
      onRetry: () => ref.invalidate(statsProvider),
      builder: (s) => _Body(s),
    ),
  );
}

class _Body extends ConsumerWidget {
  const _Body(this.s);
  final Stats s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final due = s.dueCards;
    final retention = s.retention;
    final decks = <String, List<Flashcard>>{};
    for (final c in [...s.cards]..sort((a, b) => a.front.compareTo(b.front))) {
      (decks[c.deck] ??= []).add(c);
    }
    final names = decks.keys.toList()..sort();
    final forecast = s.forecast();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Semantics(
                          label: retention == null
                              ? 'No reviews yet'
                              : 'Retention ${(retention * 100).round()} percent',
                          child: Ring(
                            value: retention ?? 0,
                            size: 84,
                            stroke: 8,
                            child: Text(
                              retention == null ? '–' : '${(retention * 100).round()}%',
                              style: t.titleMedium?.merge(tabular),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 200, maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                due.isEmpty
                                    ? 'Nothing due'
                                    : '${due.length} ${due.length == 1 ? 'card' : 'cards'} due',
                                style: t.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.cards.isEmpty
                                    ? 'Turn what you learn into questions. Each one returns just before you would forget it.'
                                    : '${s.reviewsToday} reviewed today · ${s.matureCards} of ${s.cards.length} held three weeks or more',
                                style: t.bodyMedium?.copyWith(color: muted(context)),
                              ),
                              if (due.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => startReview(context),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Begin review'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (s.cards.isEmpty)
                  const EmptyState(
                    icon: Icons.style_outlined,
                    title: 'No cards yet',
                    message: 'Add a card with a question on the front and the answer on the back.',
                  )
                else ...[
                  SectionCard(
                    title: 'The week ahead',
                    child: BarChart(
                      values: forecast,
                      labels: [
                        for (var d = 0; d < forecast.length; d++)
                          d == 0 ? 'today' : _weekday(addDays(s.today, d)),
                      ],
                      unit: ' cards',
                      highlight: 0,
                      height: 80,
                    ),
                  ),
                  for (final name in names)
                    SectionCard(
                      title: name,
                      trailing: Text(
                        '${decks[name]!.length}',
                        style: t.bodyMedium?.copyWith(color: muted(context)),
                      ),
                      child: Column(
                        children: [
                          for (final c in decks[name]!)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.front, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                c.due.compareTo(s.today) <= 0
                                    ? 'Due now'
                                    : 'Next ${relativeDay(c.due, s.today)}',
                              ),
                              onTap: () => cardDialog(context, ref, card: c),
                              onLongPress: () async {
                                if (await askSure(context, 'Delete card?', c.front) && context.mounted) {
                                  await ref.mutate((x) => x.book.removeCard(c.id));
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _weekday(String day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.parse('${day}T00:00:00').weekday - 1];

/// Adds a card, or edits [card]'s text (its schedule is kept).
Future<void> cardDialog(BuildContext context, WidgetRef ref, {Flashcard? card}) async {
  final cards = await ref.read(statsProvider.future).then((s) => s.cards);
  if (!context.mounted) return;
  final front = TextEditingController(text: card?.front),
      back = TextEditingController(text: card?.back),
      deck = TextEditingController(text: card?.deck ?? 'General');
  final decks = {for (final c in cards) c.deck}.toList()..sort();
  await showFormDialog(
    context,
    title: card == null ? 'New card' : 'Edit card',
    fields: (setState) => [
      Field(front, 'Front: the question', lines: 2, autofocus: true),
      Field(back, 'Back: the answer', lines: 3),
      Field(deck, 'Deck', hint: decks.isEmpty ? null : decks.join(', ')),
    ],
    onSave: () async {
      if (front.text.trim().isEmpty || back.text.trim().isEmpty) return 'Fill in both sides.';
      await ref.mutate(
        (s) => s.book.saveCard(
          front.text.trim(),
          back.text.trim(),
          today: today(),
          deck: deck.text.trim().ifEmpty('General'),
          courseId: card?.courseId,
          existing: card,
        ),
      );
      return null;
    },
  );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

Future<void> startReview(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewSession()));

/// Goes through today's due cards one at a time. A card marked Again comes
/// back at the end of the queue.
class ReviewSession extends ConsumerStatefulWidget {
  const ReviewSession({super.key});

  @override
  ConsumerState<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends ConsumerState<ReviewSession> {
  List<Flashcard>? _queue;
  var _shown = false, _done = 0, _busy = false;
  final _typed = TextEditingController();
  bool? _matched;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// Reveals the back; if an answer was typed, says whether it matches.
  void _reveal(Flashcard c) => setState(() {
    _shown = true;
    _matched = _typed.text.trim().isEmpty ? null : answerMatches(_typed.text, c.back);
  });

  @override
  void initState() {
    super.initState();
    ref.read(statsProvider.future).then((s) {
      if (mounted) setState(() => _queue = s.dueCards);
    });
  }

  Future<void> _grade(Flashcard c, Grade g) async {
    if (_busy) return;
    setState(() => _busy = true);
    final day = today();
    await ref.mutate((s) => s.book.reviewCard(c, g, today: day));
    final n = nextSchedule(c, g, day);
    setState(() {
      _queue!.removeAt(0);
      // Forgotten: see it again, with its new schedule, before finishing.
      if (n.due == day) {
        _queue!.add(
          c.copyWith(interval: n.interval, ease: n.ease, reps: n.reps, lapses: n.lapses, due: n.due),
        );
      }
      _done++;
      _shown = false;
      _matched = null;
      _typed.clear();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _queue;
    final card = q == null || q.isEmpty ? null : q.first;
    return Backdrop(
      child: Scaffold(
        appBar: AppBar(title: Text(q == null ? 'Review' : '${q.length} left')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: q == null
                    ? const CircularProgressIndicator()
                    : card == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.spa_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 16),
                          Text('All clear.', style: t.headlineSmall),
                          const SizedBox(height: 6),
                          Text(
                            '$_done ${_done == 1 ? 'review' : 'reviews'} done. Rest; the rest will wait.',
                            style: t.bodyLarge?.copyWith(color: muted(context)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(card.deck, style: t.labelLarge?.copyWith(color: muted(context))),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SelectableText(card.front, style: t.headlineSmall),
                                      if (_shown) ...[
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          child: Divider(color: hairline(context)),
                                        ),
                                        if (_matched != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Text(
                                              _matched!
                                                  ? 'Your answer matches.'
                                                  : 'Compare with your answer.',
                                              style: t.labelLarge?.copyWith(
                                                color: _matched!
                                                    ? Theme.of(context).colorScheme.primary
                                                    : muted(context),
                                              ),
                                            ),
                                          ),
                                        SelectableText(card.back, style: t.titleMedium),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_shown) ...[
                            TextField(
                              controller: _typed,
                              decoration: const InputDecoration(
                                labelText: 'Type your answer (optional)',
                                helperText: 'Capitals, spacing and punctuation do not matter.',
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _reveal(card),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: () => _reveal(card), child: const Text('Show answer')),
                          ] else
                            Row(
                              children: [
                                for (final g in Grade.values)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: _GradeButton(card, g, onPressed: () => _grade(card, g)),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton(this.card, this.grade, {required this.onPressed});
  final Flashcard card;
  final Grade grade;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final days = nextSchedule(card, grade, today()).interval;
    final when = days == 0 ? 'today' : '${days}d';
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(grade.label),
        Text(when, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
    const pad = EdgeInsets.symmetric(vertical: 10);
    return grade == Grade.good
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(padding: pad),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(padding: pad),
            child: child,
          );
  }
}
