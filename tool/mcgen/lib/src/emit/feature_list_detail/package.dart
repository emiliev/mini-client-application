// The list-detail package files: pubspec.yaml (its lists come from the
// generated code's use-graph), l10n.yaml, the ARBs and the `.feature` files.
// BUILD.bazel is `mcgen buildgen`'s (T-0074, ADR-0018) and the root-import
// list `mcgen wire`'s.

import 'dart:convert';

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

const _brick = 'feature_list_detail_package';

void emitPackage(EmitContext ctx, LdModel m) {
  for (final f in m.spec.bdd) {
    ctx.file(
      'test/feature/${f.feature}.feature',
      renderFeature(f, rules: {for (final r in m.spec.rules) r.id: r}),
    );
  }
  _arbs(ctx, m);
  // Read now, not when the deferred files are built, so the archetype's
  // unused-prose check sees the slot.
  final pubspec = m.optionalText('pubspec.preamble');
  for (final path in ['pubspec.yaml', 'l10n.yaml']) {
    ctx.deferred(
      path,
      (graph) => ctx.bricks[_brick].render(
        _vars(ctx, m, graph, pubspec: pubspec),
      )[path]!,
    );
  }
}

void _arbs(EmitContext ctx, LdModel m) {
  final l10n = m.spec.l10n!;
  final first = l10n.locales.first;
  // Lint reports a missing text; these errors become diagnostics too.
  String textOf(L10nStringSpec s, String locale) {
    final text = s.text[locale];
    if (text != null) return text;
    if (locale != 'en_XA') {
      throw StateError('${s.path}: "${s.key}" has no "$locale" text');
    }
    final source = s.text[first];
    if (source == null) {
      throw StateError(
        '${s.path}: "${s.key}" has no "$first" text to pseudo-translate',
      );
    }
    return pseudo(source);
  }

  String meta(L10nStringSpec s) => [
    if (s.description != null) '"description": ${jsonEncode(s.description)}',
    if (s.placeholders.isNotEmpty)
      '"placeholders": ${jsonEncode(s.placeholders)}',
  ].join(', ');

  for (final locale in l10n.locales) {
    final template = locale == first;
    final lines = [
      '"@@locale": ${jsonEncode(locale)}',
      for (final s in l10n.strings) ...[
        '${jsonEncode(s.key)}: ${jsonEncode(textOf(s, locale))}',
        if (template && meta(s).isNotEmpty)
          '${jsonEncode('@${s.key}')}: {${meta(s)}}',
      ],
    ];
    ctx.file(
      'lib/src/l10n/${m.module}_$locale.arb',
      '{\n${lines.map((l) => '  $l').join(',\n')}\n}\n',
    );
  }
}

/// A pseudo-translation (en_XA, R24): accented, bracketed and about 40 %
/// longer, so truncation and hard-coded strings show up in tests. ICU syntax
/// is left alone: a `{placeholder}` keeps its name, and a plural or select
/// keeps its argument, keyword and selectors, with only its messages
/// accented, so gen-l10n parses the result as it parses [text].
String pseudo(String text) =>
    '[${_accentMessage(text)} ${'~' * (text.length * 2 / 5).ceil()}]';

const _accents = {
  'a': 'à', 'b': 'ƀ', 'c': 'ç', 'd': 'ð', 'e': 'é', 'f': 'f', 'g': 'ĝ', //
  'h': 'ĥ', 'i': 'í', 'j': 'ĵ', 'k': 'ķ', 'l': 'ļ', 'm': 'ɱ', 'n': 'ñ', //
  'o': 'ó', 'p': 'þ', 'q': 'ǫ', 'r': 'ŕ', 's': 'š', 't': 'ţ', 'u': 'ú', //
  'v': 'ṽ', 'w': 'ŵ', 'x': 'ẋ', 'y': 'ý', 'z': 'ž', 'A': 'À', 'C': 'Ç', //
  'D': 'Ð', 'E': 'É', 'G': 'Ĝ', 'H': 'Ĥ', 'I': 'Í', 'L': 'Ļ', 'N': 'Ñ', //
  'O': 'Ó', 'S': 'Š', 'T': 'Ţ', 'U': 'Ú', 'Y': 'Ý', 'Z': 'Ž',
};

/// The index of the `}` that closes the `{` at [open].
int _closing(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}' && --depth == 0) return i;
  }
  throw FormatException('unbalanced "{" in the ICU message', s, open);
}

/// [s] with its literal text accented and its ICU arguments kept.
String _accentMessage(String s) {
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c != '{') {
      b.write(_accents[c] ?? c);
      i++;
      continue;
    }
    final end = _closing(s, i);
    final body = s.substring(i + 1, end);
    final parts = body.split(',');
    final kind = parts.length > 1 ? parts[1].trim() : '';
    if (kind == 'plural' || kind == 'select' || kind == 'selectordinal') {
      // `{name, plural, sel{message} sel{message}}`: keep all but the
      // messages, which are messages in their own right.
      final head = '${parts[0]},${parts[1]},';
      final cases = body.substring(head.length);
      b.write('{$head');
      var j = 0;
      while (j < cases.length) {
        if (cases[j] == '{') {
          final close = _closing(cases, j);
          b.write('{${_accentMessage(cases.substring(j + 1, close))}}');
          j = close + 1;
        } else {
          b.write(cases[j]);
          j++;
        }
      }
      b.write('}');
    } else {
      // A placeholder, or a number or date argument: verbatim.
      b.write('{$body}');
    }
    i = end + 1;
  }
  return b.toString();
}

Set<String> _packagesOf(UseGraph g, bool Function(String path) where) => {
  for (final l in g.libraries.values)
    if (where(l.library.path))
      for (final p in l.packages)
        if (p != g.package) p,
};

Map<String, Object?> _vars(
  EmitContext ctx,
  LdModel m,
  UseGraph g, {
  required String? pubspec,
}) {
  final spec = m.spec;
  // Codegen runtimes the source never names: injectable's output uses get_it
  // and json_serializable's json_annotation; gen-l10n's output uses
  // flutter_localizations and intl.
  final lib = {
    ..._packagesOf(g, (p) => p.startsWith('lib/')),
    ...spec.deps,
    'get_it',
    if (m.dtos.isNotEmpty) 'json_annotation',
    'flutter_localizations',
    'intl',
    // The root-import list's (`lib/src/di/flow_scope.dart`, which `mcgen
    // wire` writes since T-0074): the API's Dio and the blocs' Monitoring,
    // over mc_di's RootImport, whatever the other files import.
    'dio',
    'mc_di',
    'mc_monitoring',
  };
  final testFiles = _packagesOf(g, (p) => !p.startsWith('lib/'));
  final dev = {
    ...testFiles.difference(lib),
    ...spec.devDeps,
    'mc_analysis',
    'mc_test_steps',
  };
  String entry(String p) => ctx.packages.pubspecEntry(p);
  final description = spec.description;
  if (description == null) {
    throw StateError('${spec.file}: list_detail needs a description');
  }
  return {
    'pubspec_preamble': pubspec == null
        ? ''
        : commentLines(pubspec).replaceAll(RegExp('^//', multiLine: true), '#'),
    'name': m.module,
    'pascal': m.pascal,
    'description': description,
    'sdk': ctx.config.sdkConstraint,
    'flutter':
        ctx.config.flutterConstraint ??
        (throw StateError(
          'tool/mcgen/mcgen.yaml needs dart.flutter_constraint for a Flutter feature',
        )),
    'dependencies': [
      for (final p in (lib.toList()..sort())) {'entry': entry(p)},
    ],
    'dev_dependencies': [
      for (final p in (dev.toList()..sort())) {'entry': entry(p)},
    ],
  };
}
