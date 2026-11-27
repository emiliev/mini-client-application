// Diagnostics with a precise location: `file:line:col`, plus the YAML path.

import 'package:yaml/yaml.dart';

/// One problem in a spec or a module.
class Diagnostic implements Comparable<Diagnostic> {
  const Diagnostic({
    required this.code,
    required this.message,
    required this.file,
    this.line = 0,
    this.column = 0,
    this.yamlPath = '',
  });

  /// A diagnostic at [node]'s span (1-based line and column).
  factory Diagnostic.at(
    YamlNode? node, {
    required String code,
    required String message,
    required String file,
    String yamlPath = '',
  }) {
    final start = node?.span.start;
    return Diagnostic(
      code: code,
      message: message,
      file: file,
      line: start == null ? 0 : start.line + 1,
      column: start == null ? 0 : start.column + 1,
      yamlPath: yamlPath,
    );
  }

  /// A stable rule id, e.g. `layering` or `schema`.
  final String code;
  final String message;

  /// The file, relative to the root (never absolute in reports).
  final String file;
  final int line;
  final int column;

  /// Where in the YAML document, e.g. `entities[0].fields[2].type`.
  final String yamlPath;

  @override
  String toString() {
    final loc = line > 0 ? '$file:$line:$column' : file;
    final at = yamlPath.isEmpty ? '' : '$yamlPath: ';
    return '$loc: error [$code] $at$message';
  }

  @override
  int compareTo(Diagnostic other) {
    final f = file.compareTo(other.file);
    if (f != 0) return f;
    final l = line.compareTo(other.line);
    if (l != 0) return l;
    final c = column.compareTo(other.column);
    if (c != 0) return c;
    final k = code.compareTo(other.code);
    if (k != 0) return k;
    return message.compareTo(other.message);
  }
}

/// Thrown when a step cannot go on; carries every diagnostic found so far.
class McgenException implements Exception {
  McgenException(this.diagnostics);

  McgenException.single(Diagnostic d) : diagnostics = [d];

  /// Message-only failure (no location).
  McgenException.message(String file, String code, String message)
    : diagnostics = [Diagnostic(code: code, message: message, file: file)];

  final List<Diagnostic> diagnostics;

  @override
  String toString() => diagnostics.join('\n');
}
