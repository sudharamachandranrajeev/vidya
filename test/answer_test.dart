import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/domain/answer.dart';

void main() {
  group('typed-answer grading is lenient', () {
    test('ignores case, spacing and punctuation', () {
      expect(answerMatches('  PARIS ', 'Paris'), isTrue);
      expect(answerMatches('new   york', 'New York!'), isTrue);
    });

    test('ignores a leading article', () {
      expect(answerMatches('mitochondria', 'The mitochondria'), isTrue);
      expect(answerMatches('an apple', 'apple'), isTrue);
    });

    test('accepts any listed synonym, or the whole back', () {
      const back = 'car / automobile; motorcar';
      for (final ok in ['Car', 'automobile', 'MOTORCAR', 'car / automobile; motorcar']) {
        expect(answerMatches(ok, back), isTrue, reason: ok);
      }
    });

    test('brackets are optional', () {
      expect(answerMatches('colour', 'colour (British)'), isTrue);
      expect(answerMatches('colour british', 'colour (British)'), isTrue);
    });

    test('still rejects wrong or empty answers', () {
      expect(answerMatches('London', 'Paris'), isFalse);
      expect(answerMatches('', 'Paris'), isFalse);
      expect(answerMatches('  ', 'Paris'), isFalse);
      expect(answerMatches('car park', 'car / automobile'), isFalse);
    });

    test('works on non-Latin text', () {
      expect(answerMatches('विद्या', 'विद्या'), isTrue);
    });
  });
}
