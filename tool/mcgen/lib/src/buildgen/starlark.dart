// Just enough Starlark to merge a generated BUILD file with the one on disk
// (T-0074, ADR-0018): top-level statements with the prose above them, their
// code tokens (comments dropped), Gazelle-style `# keep` list items, and the
// hand region at the end of the file.
//
// It is not a Starlark parser: it splits a file into top-level statements by
// bracket depth, which is all buildgen needs to recognise a statement it
// would write (the same key) and to tell whether the two say the same thing
// (the same code tokens).

/// The marker id of a BUILD file's hand region.
const handRegionId = 'build';

/// `# mcgen:keep build`, the line that opens the hand region.
const handRegionStart = '# mcgen:keep $handRegionId';

/// `# mcgen:end build`, the line that closes it.
const handRegionEnd = '# mcgen:end $handRegionId';

/// A list item that a `# keep` comment on its line keeps through every
/// regeneration (Gazelle's convention).
const keepComment = '# keep';

enum TokenKind { string, word, punct, comment, newline }

class Token {
  const Token(this.kind, this.text, this.line);

  final TokenKind kind;
  final String text;

  /// 0-based line of the token's first character.
  final int line;

  @override
  String toString() => text;
}

/// The tokens of [source]: strings, words (names, numbers), punctuation,
/// comments and newlines. Whitespace is dropped.
List<Token> tokenize(String source) {
  final out = <Token>[];
  var i = 0;
  var line = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == '\n') {
      out.add(Token(TokenKind.newline, '\n', line));
      line++;
      i++;
    } else if (c == ' ' || c == '\t' || c == '\r') {
      i++;
    } else if (c == '#') {
      final end = source.indexOf('\n', i);
      final stop = end < 0 ? source.length : end;
      out.add(Token(TokenKind.comment, source.substring(i, stop), line));
      i = stop;
    } else if (c == '"' || c == "'") {
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      var j = i + quote.length;
      final startLine = line;
      while (j < source.length && !source.startsWith(quote, j)) {
        if (source[j] == '\\') j++;
        if (j < source.length && source[j] == '\n') line++;
        j++;
      }
      if (j >= source.length) {
        throw FormatException('unterminated string', source, i);
      }
      j += quote.length;
      out.add(Token(TokenKind.string, source.substring(i, j), startLine));
      i = j;
    } else if (RegExp(r'[A-Za-z0-9_.]').hasMatch(c)) {
      var j = i;
      while (j < source.length &&
          RegExp(r'[A-Za-z0-9_.]').hasMatch(source[j])) {
        j++;
      }
      out.add(Token(TokenKind.word, source.substring(i, j), line));
      i = j;
    } else {
      // Two-character operators are kept whole so `==` never equals `= =`.
      final two = i + 1 < source.length ? source.substring(i, i + 2) : '';
      final op = const {'==', '!=', '<=', '>=', '+=', '**', '//'}.contains(two)
          ? two
          : c;
      out.add(Token(TokenKind.punct, op, line));
      i += op.length;
    }
  }
  return out;
}

/// One top-level statement.
class Statement {
  Statement(this.lead, this.text, this.tokens);

  /// The lines above it back to the previous statement: blank lines and the
  /// comments that document it (prose, which buildgen carries over).
  final String lead;

  /// The statement itself, from its first character to its closing line's
  /// newline.
  final String text;

  /// Its tokens, comments and newlines included.
  final List<Token> tokens;

  /// The code tokens: what buildgen compares.
  late final List<String> code = [
    for (final t in tokens)
      if (t.kind != TokenKind.comment && t.kind != TokenKind.newline) t.text,
  ];

  /// What identifies the statement across regenerations: `load:<file>`,
  /// `package`, `var:<NAME>` or `rule:<name>` (the call's `name = "..."`,
  /// unquoted, so a comprehension's `"_%s_freezed"` is `rule:_%s_freezed`).
  late final String key = _keyOf(code);

  /// Strings marked `# keep` on their line, by the attribute (or variable)
  /// whose list holds them.
  late final Map<String, Set<String>> kept = _kept(tokens);

  /// The `"key": "value"` pairs of a dict statement, in order.
  List<(String, String)> get stringPairs => [
    for (var i = 0; i + 2 < code.length; i++)
      if (_isString(code[i]) && code[i + 1] == ':' && _isString(code[i + 2]))
        (_unquote(code[i]), _unquote(code[i + 2])),
  ];

  /// The string value of the first `name = "..."` in the statement.
  String? attr(String name) {
    for (var i = 0; i + 2 < code.length; i++) {
      if (code[i] == name && code[i + 1] == '=' && _isString(code[i + 2])) {
        return _unquote(code[i + 2]);
      }
    }
    return null;
  }

  /// The code with the items of every list and dict sorted: equal for two
  /// statements that differ only in the order of their items (which nothing
  /// in the repo's BUILD files depends on: srcs, deps, data, tags, globs).
  late final String unorderedCode = _unordered(code);

  bool sameCode(Statement other) {
    if (code.length != other.code.length) return false;
    for (var i = 0; i < code.length; i++) {
      if (code[i] != other.code[i]) return false;
    }
    return true;
  }
}

bool _isString(String s) => s.startsWith('"') || s.startsWith("'");

String _unordered(List<String> code) {
  var i = 0;
  // Reads tokens up to the closer, sorting the comma-separated items of a
  // `[...]` or `{...}`; `(...)` keeps its order (arguments, comprehensions).
  String group(String? closer, bool sortItems) {
    final items = <String>[];
    final cur = StringBuffer();
    while (i < code.length) {
      final t = code[i++];
      if (t == closer) break;
      if (t == '[' || t == '{') {
        final close = t == '[' ? ']' : '}';
        cur.write('$t${group(close, true)}$close');
      } else if (t == '(') {
        cur.write('(${group(')', false)})');
      } else if (t == ',' && sortItems) {
        items.add('$cur');
        cur.clear();
      } else {
        cur
          ..write(t)
          ..write(' ');
      }
    }
    if ('$cur'.isNotEmpty) items.add('$cur');
    if (sortItems) items.sort();
    return items.join(',');
  }

  return group(null, false);
}

String _unquote(String s) {
  if (s.startsWith('"""') || s.startsWith("'''")) {
    return s.substring(3, s.length - 3);
  }
  return s.substring(1, s.length - 1);
}

String _keyOf(List<String> code) {
  if (code.isEmpty) return '';
  if (code.length >= 3 && code[0] == 'load' && code[1] == '(') {
    return 'load:${_unquote(code[2])}';
  }
  if (code[0] == 'package' && code.length > 1 && code[1] == '(') {
    return 'package';
  }
  if (code.length > 1 && code[1] == '=' && code[0].startsWith('_') ||
      code.length > 1 && code[1] == '=' && code[0] == code[0].toUpperCase()) {
    return 'var:${code[0]}';
  }
  for (var i = 0; i + 2 < code.length; i++) {
    if (code[i] == 'name' && code[i + 1] == '=' && code[i + 2].length > 1) {
      final v = code[i + 2];
      if (v.startsWith('"') || v.startsWith("'")) return 'rule:${_unquote(v)}';
    }
  }
  return 'expr:${code.take(4).join(' ')}';
}

Map<String, Set<String>> _kept(List<Token> tokens) {
  final out = <String, Set<String>>{};
  // The attribute each open bracket belongs to: the word before the `=` that
  // precedes it (`deps = [`, `deps = _TEST_DEPS + [`), or the variable.
  final owners = <String?>[];
  String? pendingName;
  String? lastAssigned;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind == TokenKind.word &&
        i + 1 < tokens.length &&
        tokens[i + 1].text == '=') {
      pendingName = t.text;
    }
    if (t.text == '=' && pendingName != null) lastAssigned = pendingName;
    if (t.kind == TokenKind.punct && (t.text == '[' || t.text == '{')) {
      owners.add(lastAssigned);
    } else if (t.kind == TokenKind.punct && (t.text == ']' || t.text == '}')) {
      if (owners.isNotEmpty) owners.removeLast();
    } else if (t.kind == TokenKind.punct &&
        t.text == ',' &&
        owners.length <= 1) {
      // A new argument of the call (or item of the top-level list).
    }
    if (t.kind == TokenKind.string && owners.isNotEmpty) {
      // A `# keep` later on the same line keeps this string.
      for (var j = i + 1; j < tokens.length; j++) {
        final n = tokens[j];
        if (n.kind == TokenKind.newline) break;
        if (n.kind == TokenKind.comment) {
          if (n.text.trim() == keepComment) {
            (out[owners.last ?? ''] ??= <String>{}).add(_unquote(t.text));
          }
          break;
        }
      }
    }
  }
  return out;
}

/// A BUILD file split for merging.
class BuildFile {
  BuildFile._(this.statements, this.trailer, this.hand, this.handStatements);

  /// Parses [source]. Throws [FormatException] on unbalanced brackets or
  /// damaged hand-region markers.
  factory BuildFile.parse(String source) {
    final lines = source.split('\n');
    var start = -1;
    var end = -1;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].trim();
      if (l == handRegionStart) {
        if (start >= 0) {
          throw FormatException('a second "$handRegionStart"', source);
        }
        start = i;
      } else if (l == handRegionEnd) {
        if (start < 0 || end >= 0) {
          throw FormatException('"$handRegionEnd" without its start', source);
        }
        end = i;
      } else if (l.startsWith('# mcgen:keep') || l.startsWith('# mcgen:end')) {
        throw FormatException(
          'a BUILD file has one keep region, "$handRegionId": ${lines[i]}',
          source,
        );
      }
    }
    if (start >= 0 && end < 0) {
      throw FormatException('"$handRegionStart" is never closed', source);
    }
    String? hand;
    var main = source;
    if (start >= 0) {
      hand = lines.sublist(start + 1, end).join('\n');
      if (end + 1 < lines.length &&
          lines.sublist(end + 1).join().trim() != '') {
        throw FormatException(
          'the hand region must end the file (found text after line ${end + 1})',
          source,
        );
      }
      main = '${lines.sublist(0, start).join('\n')}\n';
    }
    final (statements, trailer) = _split(main);
    final handStatements = hand == null
        ? const <Statement>[]
        : _split('$hand\n').$1;
    return BuildFile._(statements, trailer, hand, handStatements);
  }

  final List<Statement> statements;

  /// What follows the last statement (normally nothing).
  final String trailer;

  /// The hand region's body (the lines between the markers), or null.
  final String? hand;

  /// The statements of the hand region.
  final List<Statement> handStatements;

  /// Keys the hand region defines: buildgen writes none of these itself.
  Set<String> get handKeys => {for (final s in handStatements) s.key};

  Statement? operator [](String key) {
    for (final s in statements) {
      if (s.key == key) return s;
    }
    return null;
  }
}

(List<Statement>, String) _split(String source) {
  final tokens = tokenize(source);
  final lines = source.split('\n');
  // Offsets of each line's first character.
  final offsets = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source[i] == '\n') offsets.add(i + 1);
  }
  final out = <Statement>[];
  var depth = 0;
  int? first;
  var leadFrom = 0; // line index where the current lead starts
  final current = <Token>[];
  for (final t in tokens) {
    if (first == null) {
      if (t.kind == TokenKind.comment || t.kind == TokenKind.newline) continue;
      first = t.line;
    }
    current.add(t);
    if (t.kind == TokenKind.punct && '([{'.contains(t.text)) depth++;
    if (t.kind == TokenKind.punct && ')]}'.contains(t.text)) depth--;
    if (depth < 0) throw FormatException('unbalanced brackets', source);
    if (depth == 0 && t.kind == TokenKind.newline) {
      final from = offsets[first];
      final to = offsets[t.line + 1];
      final lead = first > leadFrom
          ? source.substring(offsets[leadFrom], from)
          : '';
      out.add(
        Statement(
          lead,
          source.substring(from, to),
          [for (final x in current) x],
        ),
      );
      current.clear();
      first = null;
      leadFrom = t.line + 1;
    }
  }
  if (depth != 0) throw FormatException('unbalanced brackets', source);
  if (first != null) {
    throw FormatException('the file does not end with a newline', source);
  }
  final trailer = leadFrom < lines.length
      ? source.substring(offsets[leadFrom])
      : '';
  return (out, trailer);
}
