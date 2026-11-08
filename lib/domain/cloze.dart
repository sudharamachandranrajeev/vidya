/// Cloze deletion: a card's front holds spans like `{{c1::Paris}}` or
/// `{{c1::Paris::a city}}` (the last part is a hint). The card hides every
/// span at once and the back may be left empty or hold extra detail.
final _span = RegExp(r'\{\{c\d+::(.*?)(?:::(.*?))?\}\}', dotAll: true);

bool isCloze(String front) => _span.hasMatch(front);

/// The front with each span hidden: `[…]` or `[hint]`.
String clozeQuestion(String front) =>
    front.replaceAllMapped(_span, (m) => (m[2] ?? '').isEmpty ? '[…]' : '[${m[2]}]');

/// The front with each span revealed.
String clozeAnswer(String front) => front.replaceAllMapped(_span, (m) => m[1]!);

/// The hidden words, in order.
List<String> clozeAnswers(String front) => [for (final m in _span.allMatches(front)) m[1]!];
