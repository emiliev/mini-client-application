// A feature's `lib/src/di/flow_scope.dart` (R17, plan 01 §4.5, T-0074): the
// root services its flow's container forwards. They are the parameter types
// of every injectable constructor, `@factoryMethod` and module member in the
// package, minus what the package registers itself and what the flow
// provides (`FeatureFlowController`, the navigator, `provide:`). That is the
// input injectable reads; this reads it from the source text (the repo's
// code is formatted, so a declaration's shape is regular).

import 'package:mcgen/src/buildgen/dart_scan.dart';
import 'package:mcgen/src/emit/common/barrel_scan.dart';
import 'package:mcgen/src/emit/common/kit_symbols.dart';
import 'package:path/path.dart' as p;

const flowScopePath = 'lib/src/di/flow_scope.dart';

final _annotation = RegExp(
  r'^@(injectable|lazySingleton|singleton|module|Injectable|LazySingleton|Singleton)\b(\([^)]*\))?',
  multiLine: true,
);
final _classDecl = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface)\s+)*class\s+(\w+)',
  multiLine: true,
);

/// The text from [open] (an opening bracket) to its closing bracket,
/// exclusive.
String _inside(String s, int open) {
  final o = s[open];
  final c = const {'(': ')', '{': '}', '[': ']', '<': '>'}[o]!;
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == o) depth++;
    if (s[i] == c && --depth == 0) return s.substring(open + 1, i);
  }
  throw FormatException('unbalanced "$o"', s, open);
}

/// [s] split at its top-level commas.
List<String> _splitTop(String s) {
  final out = <String>[];
  var depth = 0;
  var from = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if ('([{<'.contains(c)) depth++;
    if (')]}>'.contains(c)) depth--;
    if (c == ',' && depth == 0) {
      out.add(s.substring(from, i));
      from = i + 1;
    }
  }
  out.add(s.substring(from));
  return [
    for (final x in out)
      if (x.trim().isNotEmpty) x.trim(),
  ];
}

String _baseType(String type) =>
    type.replaceAll('?', '').split('<').first.trim();

/// The type of one parameter, or null for `super.x`.
String? _paramType(String param, String classBody) {
  // Passed by the caller at resolve time, not resolved from the container.
  if (param.contains('@factoryParam')) return null;
  final x = param
      .replaceAll(RegExp(r'@\w+(\([^)]*\))?\s*'), '')
      .replaceAll(RegExp(r'^[{\[]|[}\]]$'), '')
      .replaceFirst(RegExp(r'^required\s+'), '')
      .split('=')
      .first
      .trim();
  if (x.startsWith('super.')) return null;
  if (x.startsWith('this.')) {
    final field = x.substring(5);
    final m = RegExp(
      r'final\s+([\w<>?, ]+?)\s+' + RegExp.escape(field) + r'\s*;',
    ).firstMatch(classBody);
    if (m == null) {
      throw StateError('no field "$field" for the parameter "this.$field"');
    }
    return m.group(1)!.trim();
  }
  final parts = x.split(RegExp(r'\s+'));
  if (parts.length < 2) throw StateError('an untyped parameter "$param"');
  return parts.sublist(0, parts.length - 1).join(' ');
}

/// One injectable declaration's dependencies and what it registers.
class _Injectable {
  _Injectable(this.registers, this.needs, this.file);

  final Set<String> registers;

  /// Parameter types (full text).
  final List<String> needs;
  final DartFile file;
}

List<_Injectable> _injectables(DartFile f) {
  final out = <_Injectable>[];
  final text = f.text;
  for (final a in _annotation.allMatches(text)) {
    final cls = _classDecl.firstMatch(text.substring(a.end));
    if (cls == null) continue;
    final name = cls.group(1)!;
    final bodyOpen = text.indexOf('{', a.end + cls.end);
    final body = _inside(text, bodyOpen);
    if (a.group(1) == 'module') {
      // `@lazySingleton T name(params) =>`, or a getter `T get name =>`.
      final member = RegExp(
        r'^\s*@\w+(?:\([^)]*\))?\s*\n\s*([\w<>?]+)\s+(get\s+)?(\w+)\s*(\()?',
        multiLine: true,
      );
      for (final m in member.allMatches(body)) {
        final needs = <String>[];
        if (m.group(4) != null) {
          final open = body.indexOf('(', m.start + m.group(0)!.length - 1);
          for (final prm in _splitTop(_inside(body, open))) {
            final t = _paramType(prm, body);
            if (t != null) needs.add(t);
          }
        }
        out.add(_Injectable({_baseType(m.group(1)!)}, needs, f));
      }
      continue;
    }
    final as = RegExp(r'as:\s*(\w+)').firstMatch(a.group(2) ?? '');
    final ctor = RegExp(
      r'^\s*(?:const\s+|factory\s+)?' +
          RegExp.escape(name) +
          r'(?:\.\w+)?\s*\(',
      multiLine: true,
    ).firstMatch(body);
    final needs = <String>[];
    if (ctor != null) {
      final open = body.indexOf('(', ctor.start + ctor.group(0)!.length - 1);
      for (final prm in _splitTop(_inside(body, open))) {
        final t = _paramType(prm, body);
        if (t != null) needs.add(t);
      }
    }
    out.add(_Injectable({as?.group(1) ?? name}, needs, f));
  }
  return out;
}

/// A root import: its type and the library that declares it.
typedef RootImport = ({String type, String uri});

/// The root imports of the package [name] at [dir] (absolute).
List<RootImport> rootImports(String name, String dir, String repoRoot) {
  final lib = dartFiles(dir, 'lib');
  final injectables = [for (final f in lib) ..._injectables(f)];
  final registered = {for (final i in injectables) ...i.registers};
  final provided = <String>{'FeatureFlowController'};
  for (final f in lib) {
    if (f.path.startsWith('lib/src/navigator/')) {
      for (final m in _classDecl.allMatches(f.text)) {
        provided.add(m.group(1)!);
      }
    }
    if (f.path.startsWith('lib/src/flow/')) {
      for (final m in RegExp(r'register\w*<(\w+)>').allMatches(f.text)) {
        provided.add(m.group(1)!);
      }
    }
  }
  // What widgets read from the flow's scope directly (`context.di<T>()`, a
  // flow observer, a page's flag) needs a root import too.
  for (final f in lib) {
    final reads = [
      for (final m in RegExp(r'\.di<(\w+)>\(').allMatches(f.text)) m.group(1)!,
    ];
    if (reads.isNotEmpty) injectables.add(_Injectable(const {}, reads, f));
  }
  final out = <String, RootImport>{};
  for (final i in injectables) {
    for (final t in i.needs) {
      final base = _baseType(t);
      if (registered.contains(base) || provided.contains(base)) continue;
      if (out.containsKey(base)) continue;
      out[base] = (
        type: t.replaceAll('?', ''),
        uri: _uriOf(base, i.file, name, repoRoot),
      );
    }
  }
  return out.values.toList()..sort((a, b) => a.type.compareTo(b.type));
}

String _uriOf(String type, DartFile f, String self, String repoRoot) {
  final hits = <String>[];
  for (final u in f.imports) {
    if (!u.startsWith('package:') || u.startsWith('package:$self/')) continue;
    final third = thirdPartySymbols[u];
    if (third != null && third.contains(type)) {
      hits.add(u);
      continue;
    }
    final file = firstPartyLibraryFile(u, repoRoot);
    if (file != null && exportedNames(file, repoRoot).contains(type)) {
      hits.add(u);
    }
  }
  if (hits.length != 1) {
    throw StateError(
      '${f.path}: cannot tell which import declares $type '
      '(${hits.isEmpty ? 'none' : hits.join(', ')}); add it to '
      'thirdPartySymbols (emit/common/kit_symbols.dart) if it is a '
      'third-party type',
    );
  }
  return hits.single;
}

/// The camelCase `<module>RootImports` name, or the one the file on disk
/// declares.
String rootImportsName(String module, String? existing) {
  if (existing != null) {
    final m = RegExp(r'const List<RootImport<Object>> (\w+) =')
        .firstMatch(existing);
    if (m != null) return m.group(1)!;
  }
  final parts = module.split('_');
  return [
    parts.first,
    for (final x in parts.skip(1)) '${x[0].toUpperCase()}${x.substring(1)}',
    'RootImports',
  ].join();
}

/// The default doc comment of a generated `flow_scope.dart`.
const flowScopeDoc =
    '/// The root services this flow\'s container forwards (R17): the parameter\n'
    '/// types of every injectable constructor and `@factoryMethod` in the package,\n'
    '/// minus what the package registers itself and what the flow provides\n'
    '/// (`FeatureFlowController`, the navigator).\n'
    '///\n'
    '/// Written by `mcgen wire` from the package\'s injectable declarations\n'
    '/// (T-0074); the comment above the list is yours, the list is not.\n'
    '/// `test/flow_scope_test.dart` opens the flow over the production-shaped\n'
    '/// test root and resolves every registration, so a missing import fails a\n'
    '/// test, not the app.\n';

/// The unformatted file: imports, the doc comment (the file's own, carried
/// over, or [flowScopeDoc]) and the list. `mcgen wire` formats it.
String flowScopeFile(
  String module,
  List<RootImport> imports, {
  String? existing,
}) {
  var doc = flowScopeDoc;
  if (existing != null) {
    final m = RegExp(
      r'((?:^///.*\n)+)const List<RootImport<Object>>',
      multiLine: true,
    ).firstMatch(existing);
    if (m != null) doc = m.group(1)!;
  }
  final uris = {
    'package:mc_di/mc_di.dart',
    for (final i in imports) i.uri,
  }.toList()..sort();
  final name = rootImportsName(module, existing);
  return [
    for (final u in uris) "import '$u';",
    '',
    '${doc}const List<RootImport<Object>> $name = [',
    for (final i in imports) '  RootImport<${i.type}>(),',
    '];',
    '',
  ].join('\n');
}

/// Whether [dir] is a package wire writes a flow scope for: a feature with a
/// flow and a DI initializer.
bool hasFlowScope(String dir) =>
    dartFiles(
      dir,
      'lib',
    ).any((f) => f.path == 'lib/src/di/di_initializer.dart') &&
    dartFiles(dir, 'lib').any((f) => p.posix.dirname(f.path) == 'lib/src/flow');
