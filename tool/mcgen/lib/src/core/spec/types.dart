// The spec's two mini-syntaxes: Dart type expressions (`Page<Character>?`) and
// call signatures (`requestSignIn() -> bool`, `team(TeamRef)`).

/// A parsed Dart type expression.
class TypeExpr {
  const TypeExpr(this.name, {this.args = const [], this.nullable = false});

  /// Parses [source]; throws [FormatException] with the offending offset.
  factory TypeExpr.parse(String source) {
    final p = _TypeParser(source);
    final t = p.parseType();
    p.skipSpaces();
    if (!p.atEnd) p.fail('unexpected "${source.substring(p.pos)}"');
    return t;
  }

  final String name;
  final List<TypeExpr> args;
  final bool nullable;

  /// Every type name in this expression, outermost first.
  Iterable<String> get names sync* {
    yield name;
    for (final a in args) {
      yield* a.names;
    }
  }

  @override
  String toString() {
    final a = args.isEmpty ? '' : '<${args.join(', ')}>';
    return '$name$a${nullable ? '?' : ''}';
  }

  @override
  bool operator ==(Object other) => other is TypeExpr && '$other' == '$this';

  @override
  int get hashCode => toString().hashCode;
}

class _TypeParser {
  _TypeParser(this.src);

  final String src;
  int pos = 0;

  bool get atEnd => pos >= src.length;

  Never fail(String why) =>
      throw FormatException('invalid type "$src": $why', src, pos);

  void skipSpaces() {
    while (!atEnd && src[pos] == ' ') {
      pos++;
    }
  }

  TypeExpr parseType() {
    skipSpaces();
    final start = pos;
    while (!atEnd && RegExp(r'[A-Za-z0-9_]').hasMatch(src[pos])) {
      pos++;
    }
    if (start == pos) fail('expected a type name at offset $pos');
    final name = src.substring(start, pos);
    if (RegExp(r'^[0-9]').hasMatch(name)) fail('"$name" is not a type name');
    final args = <TypeExpr>[];
    skipSpaces();
    if (!atEnd && src[pos] == '<') {
      pos++;
      args.add(parseType());
      skipSpaces();
      while (!atEnd && src[pos] == ',') {
        pos++;
        args.add(parseType());
        skipSpaces();
      }
      if (atEnd || src[pos] != '>') fail('expected ">" at offset $pos');
      pos++;
    }
    var nullable = false;
    if (!atEnd && src[pos] == '?') {
      nullable = true;
      pos++;
    }
    return TypeExpr(name, args: args, nullable: nullable);
  }
}

/// A parsed `name(arg, ...) -> Return` signature. Arguments stay raw: an
/// archetype decides whether `search(query)` names a parameter or a type.
class Signature {
  const Signature(
    this.name, {
    this.args = const [],
    this.returns,
    this.hasParens = false,
  });

  factory Signature.parse(String source) {
    final m = RegExp(
      r'^([a-z][A-Za-z0-9]*)(?:\(([^()]*)\))?(?: -> (.+))?$',
    ).firstMatch(source);
    if (m == null) {
      throw FormatException('invalid signature "$source"', source);
    }
    final rawArgs = m.group(2);
    final args = rawArgs == null || rawArgs.trim().isEmpty
        ? const <String>[]
        : [for (final a in rawArgs.split(',')) a.trim()];
    if (args.any((a) => a.isEmpty)) {
      throw FormatException('empty argument in "$source"', source);
    }
    final ret = m.group(3);
    return Signature(
      m.group(1)!,
      args: args,
      returns: ret == null ? null : TypeExpr.parse(ret),
      hasParens: rawArgs != null,
    );
  }

  final String name;
  final List<String> args;
  final TypeExpr? returns;

  /// `open()` and `open` differ: the first is a call with no arguments.
  final bool hasParens;

  @override
  String toString() {
    final a = hasParens ? '(${args.join(', ')})' : '';
    final r = returns == null ? '' : ' -> $returns';
    return '$name$a$r';
  }
}
