import 'dart:convert';

import 'cloze.dart';

/// A card read from a file, before it is saved.
typedef ImportedCard = ({String front, String back, String deck, String image, String audio});

/// What reading a deck file produced: the usable cards and how many rows had
/// to be left out (missing a side).
typedef ImportResult = ({List<ImportedCard> cards, int skipped});

/// Reads a deck file by its name: CSV or tab-separated text (Quizlet's export,
/// Anki's plain-text export) or a Vidya share file. Throws [FormatException]
/// with a message fit for the learner when the format cannot be read.
ImportResult parseDeckFile(String name, List<int> bytes) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (ext == 'apkg' || ext == 'colpkg') {
    throw const FormatException(
      'Anki .apkg files are not yet supported. In Anki use Export → "Notes in Plain Text" '
      'and import that file, or save the cards as CSV.',
    );
  }
  final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
  if (text.trimLeft().startsWith('{')) return _fromJson(text);
  return _fromTable(text);
}

ImportResult _fromJson(String text) {
  final Object? j;
  try {
    j = jsonDecode(text);
  } on FormatException {
    throw const FormatException('This file is not valid JSON.');
  }
  if (j is! Map || j['format'] != 'vidya-decks' || j['cards'] is! List) {
    throw const FormatException('This JSON file is not a Vidya card export.');
  }
  final rows = [
    for (final c in j['cards'] as List)
      if (c is Map) [for (final k in _columns) '${c[k] ?? ''}'],
  ];
  return _collect(rows, List.of(_columns));
}

const _columns = ['front', 'back', 'deck', 'image', 'audio'];

const _aliases = {
  'front': 'front',
  'question': 'front',
  'term': 'front',
  'q': 'front',
  'back': 'back',
  'answer': 'back',
  'definition': 'back',
  'a': 'back',
  'deck': 'deck',
  'image': 'image',
  'audio': 'audio',
};

ImportResult _fromTable(String text) {
  // Anki's plain-text export starts with `#separator:tab`-style comment lines.
  final lines = text.split(RegExp(r'\r?\n'));
  final body = lines.where((l) => !l.startsWith('#')).join('\n');
  final first = body.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final delimiter = first.contains('\t')
      ? '\t'
      : (first.contains(',') ? ',' : (first.contains(';') ? ';' : '\t'));
  final rows = parseDelimited(body, delimiter).where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  if (rows.isEmpty) throw const FormatException('No cards found in this file.');

  // A header row names the columns; otherwise the first two are front and back.
  final names = [for (final c in rows.first) _aliases[c.trim().toLowerCase()] ?? ''];
  final hasHeader = names.contains('front') && names.contains('back');
  return hasHeader ? _collect(rows.skip(1).toList(), names) : _collect(rows, ['front', 'back']);
}

ImportResult _collect(List<List<String>> rows, List<String> names) {
  final cards = <ImportedCard>[];
  var skipped = 0;
  for (final r in rows) {
    String cell(String n) {
      final i = names.indexOf(n);
      return i < 0 || i >= r.length ? '' : r[i].trim();
    }

    final front = cell('front'), back = cell('back');
    if (front.isEmpty || (back.isEmpty && !isCloze(front))) {
      skipped++;
      continue;
    }
    final deck = cell('deck');
    cards.add((
      front: front,
      back: back,
      deck: deck.isEmpty ? 'Imported' : deck,
      image: cell('image'),
      audio: cell('audio'),
    ));
  }
  if (cards.isEmpty) throw const FormatException('No usable cards found: each row needs a front and a back.');
  return (cards: cards, skipped: skipped);
}

/// Splits [text] into rows of fields (RFC 4180): fields may be quoted, and a
/// quoted field may hold the delimiter, line breaks and doubled quotes.
List<List<String>> parseDelimited(String text, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"' && field.isEmpty) {
      quoted = true;
    } else if (ch == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
