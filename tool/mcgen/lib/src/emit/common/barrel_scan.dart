// What a first-party barrel exports, read from the source (P-120 (b)): the
// check behind kit_symbols.dart. A light lexical scan, not an analyzer: it
// follows `export` directives (with `show`), and otherwise collects the
// public top-level declarations of each exported file, recursively. It
// errs toward finding a name (any top-level declaration counts), which is
// what a "the table only lists exported names" check needs.

import 'dart:io';

import 'package:path/path.dart' as p;

final RegExp _export = RegExp(
  r'''^export\s+['"]([^'"]+)['"]([^;]*);''',
  multiLine: true,
);

final List<RegExp> _decls = [
  RegExp(
    r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*class\s+(\w+)',
    multiLine: true,
  ),
  RegExp(r'^(?:base\s+)?mixin\s+(\w+)', multiLine: true),
  RegExp(r'^enum\s+(\w+)', multiLine: true),
  RegExp(r'^extension\s+type\s+(?:const\s+)?(\w+)', multiLine: true),
  RegExp(r'^extension\s+(\w+)\s+on\b', multiLine: true),
  RegExp(r'^typedef\s+(\w+)', multiLine: true),
  // Functions and getters: a return type, then the name and `(`, `<` or get.
  RegExp(
    r'^[A-Za-z_$][\w$<>?, .]*?\s+(?:get\s+)?(\w+)\s*[(<]',
    multiLine: true,
  ),
  RegExp(r'^[A-Za-z_$][\w$<>?, .]*?\s+get\s+(\w+)', multiLine: true),
  // Top-level variables, typed or not.
  RegExp(
    r'^(?:const|final|var|late\s+final)\s+(?:[\w$<>?, .]+\s+)?(\w+)\s*=',
    multiLine: true,
  ),
];

const _notNames = {'if', 'for', 'while', 'switch', 'return', 'class', 'get'};

String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// The file a URI in [fromFile] names, or null when it is outside the
/// repo's first-party packages (an SDK or third-party library).
String? _resolve(String uri, String fromFile, String repoRoot) {
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    final pkg = rest.substring(0, slash);
    for (final tier in ['utility', 'feature', 'app']) {
      final f = p.join(repoRoot, tier, pkg, 'lib', rest.substring(slash + 1));
      if (File(f).existsSync()) return f;
    }
    return null;
  }
  if (uri.startsWith('dart:')) return null;
  return p.normalize(p.join(p.dirname(fromFile), uri));
}

/// The `output-class` of the l10n.yaml whose `output-localization-file` is
/// [file] (a gen-l10n output, absent from the checkout), or null.
String? _l10nClassFor(String file) {
  var dir = p.dirname(file);
  while (p.basename(dir) != 'lib' && p.dirname(dir) != dir) {
    dir = p.dirname(dir);
  }
  final yaml = File(p.join(p.dirname(dir), 'l10n.yaml'));
  if (!yaml.existsSync()) return null;
  String? value(String key) => RegExp(
    '^$key:\\s*(\\S+)',
    multiLine: true,
  ).firstMatch(yaml.readAsStringSync())?[1];
  return value('output-localization-file') == p.basename(file)
      ? value('output-class')
      : null;
}

/// The public names [libraryFile] exports (its declarations plus its export
/// closure). [repoRoot] resolves first-party `package:` URIs.
Set<String> exportedNames(String libraryFile, String repoRoot) {
  final seen = <String>{};
  Set<String> visit(String file) {
    if (!seen.add(file)) return const {};
    final source = _stripComments(File(file).readAsStringSync());
    final out = <String>{};
    for (final re in _decls) {
      for (final m in re.allMatches(source)) {
        final name = m[1]!;
        if (!name.startsWith('_') && !_notNames.contains(name)) out.add(name);
      }
    }
    for (final m in _export.allMatches(source)) {
      final combinators = m[2]!;
      final show = RegExp(r'\bshow\s+([\w$,\s]+?)(?:\bhide\b|$)')
          .firstMatch(combinators);
      final hide = RegExp(r'\bhide\s+([\w$,\s]+?)(?:\bshow\b|$)')
          .firstMatch(combinators);
      if (show != null) {
        out.addAll(
          show[1]!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
        continue;
      }
      final target = _resolve(m[1]!, file, repoRoot);
      if (target == null) continue;
      if (!File(target).existsSync()) {
        // Generated, so not in the checkout: gen-l10n's output declares the
        // class its package's l10n.yaml names.
        final l10n = _l10nClassFor(target);
        if (l10n != null) out.add(l10n);
        continue;
      }
      final names = visit(target);
      final hidden = hide == null
          ? const <String>{}
          : hide[1]!.split(',').map((s) => s.trim()).toSet();
      out.addAll(names.difference(hidden));
    }
    return out;
  }

  return visit(libraryFile);
}

/// The file of first-party library [uri] (`package:mc_x/mc_x.dart`) under
/// [repoRoot], or null.
String? firstPartyLibraryFile(String uri, String repoRoot) =>
    _resolve(uri, repoRoot, repoRoot);
