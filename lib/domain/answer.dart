/// Lenient grading of a typed answer against a card's back.
///
/// Case, spacing, punctuation and a leading "a", "an" or "the" never matter,
/// and a back that lists synonyms ("car / automobile", "big; large") accepts
/// any one of them, as well as the whole text. Text in brackets is optional.
bool answerMatches(String typed, String back) {
  final given = _normal(typed);
  if (given.isEmpty) return false;
  return _accepted(back).contains(given);
}

Set<String> _accepted(String back) {
  final forms = <String>{};
  void add(String text) {
    final n = _normal(text);
    if (n.isNotEmpty) forms.add(n);
  }

  for (final text in [back, ...back.split(RegExp(r'[/;|\n]'))]) {
    add(text);
    add(text.replaceAll(_brackets, ' '));
    add(text.replaceAll(RegExp(r'[()\[\]]'), ' '));
  }
  return forms;
}

final _brackets = RegExp(r'\([^)]*\)|\[[^\]]*\]');
final _gaps = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _article = RegExp(r'^(a|an|the) ');

String _normal(String s) => s.toLowerCase().replaceAll(_gaps, ' ').trim().replaceFirst(_article, '');
