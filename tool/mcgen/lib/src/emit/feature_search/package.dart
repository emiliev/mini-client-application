// The search package files: pubspec.yaml (its lists come from the
// generated code's use-graph plus the spec's `deps`), l10n.yaml, the ARBs
// and the `.feature` files. BUILD.bazel is the module's own until P2-08's
// buildgen; a skeleton module gets a first write (skeleton.dart).

import 'dart:convert';

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_list_detail/package.dart' show pseudo;
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _brick = 'feature_search_package';

void emitPackage(EmitContext ctx, SrModel m) {
  for (final f in m.spec.bdd) {
    ctx.file(
      'test/feature/${f.feature}.feature',
      renderFeature(f, rules: {for (final r in m.spec.rules) r.id: r}),
    );
  }
  _arbs(ctx, m);
  // Read now, not when the deferred files are built, so the archetype's
  // unused-prose check sees the slot.
  final preamble = m.optionalText('pubspec.preamble');
  for (final path in ['pubspec.yaml', 'l10n.yaml']) {
    ctx.deferred(path, (graph) {
      String entry(String p) => ctx.packages.pubspecEntry(p);
      final lib = {
        ...graph.libDeps,
        ...m.spec.deps,
        // The runtimes the generated code uses without naming them:
        // injectable's output uses get_it, gen-l10n's flutter_localizations
        // and intl.
        'get_it',
        'json_annotation',
        'flutter_localizations',
        'intl',
        // The root-import list's (`lib/src/di/flow_scope.dart`, which `mcgen
        // wire` writes since T-0074): Dio, FileStore, Monitoring and the
        // analytics port, over mc_di's RootImport.
        'dio',
        'mc_di',
        'mc_monitoring',
        'mc_storage',
      };
      final dev = {
        ...graph.devDeps.where((p) => !lib.contains(p)),
        ...m.spec.devDeps,
        'mc_analysis',
        'mc_test_steps',
      };
      final description = m.spec.description;
      if (description == null) {
        throw StateError('${m.spec.file}: a search module needs a description');
      }
      return ctx.bricks[_brick].render({
        'pubspec_preamble': preamble == null
            ? ''
            : commentLines(
                preamble,
              ).replaceAll(RegExp('^//', multiLine: true), '#'),
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
      })[path]!;
    });
  }
}

void _arbs(EmitContext ctx, SrModel m) {
  final l10n = m.spec.l10n!;
  final first = l10n.locales.first;
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

  // `block`: a description with placeholders goes on lines of its own, as
  // discovery_search writes it; otherwise one line.
  final block = m.arbBlock;
  List<String> meta(L10nStringSpec s) {
    final parts = [
      if (s.description != null) '"description": ${jsonEncode(s.description)}',
      if (s.placeholders.isNotEmpty) '"placeholders": ${_json(s.placeholders)}',
    ];
    final key = jsonEncode('@${s.key}');
    if (parts.isEmpty) return const [];
    if (block && s.placeholders.isNotEmpty) {
      return [
        '$key: {',
        for (final (i, p) in parts.indexed)
          '  $p${i < parts.length - 1 ? ',' : ''}',
        '}',
      ];
    }
    return ['$key: {${parts.join(', ')}}'];
  }

  for (final locale in l10n.locales) {
    final template = locale == first;
    final entries = <List<String>>[
      ['"@@locale": ${jsonEncode(locale)}'],
      for (final s in l10n.strings) ...[
        ['${jsonEncode(s.key)}: ${jsonEncode(textOf(s, locale))}'],
        if (template && meta(s).isNotEmpty) meta(s),
      ],
    ];
    final lines = [
      for (final (i, e) in entries.indexed)
        for (final (j, l) in e.indexed)
          '  $l${j == e.length - 1 && i < entries.length - 1 ? ',' : ''}',
    ];
    ctx.file(
      'lib/src/l10n/${m.module}_$locale.arb',
      '{\n${lines.join('\n')}\n}\n',
    );
  }
}

/// JSON with a space after each `:` and `,`: how the exemplars write
/// placeholder metadata (`{"query": {"type": "String"}}`).
String _json(Object? v) => switch (v) {
  Map() =>
    '{${v.entries.map((e) => '${jsonEncode('${e.key}')}: ${_json(e.value)}').join(', ')}}',
  List() => '[${v.map(_json).join(', ')}]',
  _ => jsonEncode(v),
};
