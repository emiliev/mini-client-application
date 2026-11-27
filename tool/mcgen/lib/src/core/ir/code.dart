// Code fragments with symbol references (plan 02 section 2.4).
//
// An emitter writes Dart as text and marks each name that may need an
// import with [ref]: `Code('final ${ref('Money')} price;')`. The marker is
// delimited by NUL characters, which cannot appear in Dart source, so a
// reference can never be confused with text.

const _open = '\u0000';
const _sep = '\u0001';

/// A reference to the top-level symbol [name], rendered as [name]. [from]
/// pins the owning library URI when the name alone is ambiguous or external
/// and unregistered.
String ref(String name, {String? from}) {
  if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(name)) {
    throw ArgumentError.value(name, 'name', 'not a Dart identifier');
  }
  return from == null ? '$_open$name$_open' : '$_open$name$_sep$from$_open';
}

/// A symbol reference found in a [Code].
class SymbolRef {
  const SymbolRef(this.name, [this.from]);

  final String name;
  final String? from;

  @override
  bool operator ==(Object other) =>
      other is SymbolRef && other.name == name && other.from == from;

  @override
  int get hashCode => Object.hash(name, from);

  @override
  String toString() => from == null ? name : '$name ($from)';
}

/// Dart text with embedded [ref] markers.
class Code {
  Code(this.source) {
    if (_open.allMatches(source).length.isOdd) {
      throw ArgumentError('unbalanced reference markers in: ${render()}');
    }
  }

  /// Joins [parts] with [separator].
  factory Code.join(Iterable<Code> parts, [String separator = '']) =>
      Code(parts.map((c) => c.source).join(separator));

  final String source;

  /// The references, in order of appearance.
  Iterable<SymbolRef> get refs sync* {
    final parts = source.split(_open);
    for (var i = 1; i < parts.length; i += 2) {
      final p = parts[i];
      final s = p.indexOf(_sep);
      yield s < 0
          ? SymbolRef(p)
          : SymbolRef(p.substring(0, s), p.substring(s + 1));
    }
  }

  /// The Dart text, references replaced by their names.
  String render() {
    final parts = source.split(_open);
    final b = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i.isEven) {
        b.write(parts[i]);
      } else {
        final s = parts[i].indexOf(_sep);
        b.write(s < 0 ? parts[i] : parts[i].substring(0, s));
      }
    }
    return b.toString();
  }

  @override
  String toString() => render();
}
