// The dashboard package files: pubspec.yaml (its lists come from the
// generated files' imports plus the spec's `deps`), l10n.yaml, the ARBs and
// the `.feature` files. BUILD.bazel is the module's own (owned) until P2-08's
// buildgen.

import 'dart:convert';

import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_dashboard/model.dart';
import 'package:mcgen/src/emit/feature_dashboard/text.dart';
import 'package:mcgen/src/emit/feature_list_detail/package.dart' show pseudo;

const _brick = 'feature_dashboard_package';

/// `package:<name>/` of an import line.
final _pkg = RegExp(r'''^import\s+['"]package:([a-z0-9_]+)/''', multiLine: true);

/// The packages [sources] import, by name.
Set<String> packagesOf(Iterable<String> sources) => {
  for (final s in sources)
    for (final m in _pkg.allMatches(s)) m[1]!,
};

void emitPackage(
  Out ctx,
  DbModel m, {
  required Iterable<String> libSources,
  required Iterable<String> testSources,
}) {
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
  final libPackages = packagesOf(libSources);
  final testPackages = packagesOf(testSources);
  for (final path in ['pubspec.yaml', 'l10n.yaml']) {
    ctx.deferred(path, (_) {
      String entry(String p) => ctx.packages.pubspecEntry(p);
      final lib = {
        ...libPackages,
        ...m.spec.deps,
        // The runtimes the generated code uses without naming them:
        // injectable's output uses get_it, json_serializable's
        // json_annotation, gen-l10n's flutter_localizations and intl.
        'get_it',
        'json_annotation',
        'flutter_localizations',
        'intl',
      }..remove(m.module);
      final dev = {
        ...testPackages.where((p) => !lib.contains(p)),
        ...m.spec.devDeps.where((p) => !lib.contains(p)),
        'mc_analysis',
        'mc_test_steps',
      }..remove(m.module);
      return ctx.bricks[_brick].render({
        'pubspec_preamble': preamble == null
            ? ''
            : commentLines(
                preamble,
              ).replaceAll(RegExp('^//', multiLine: true), '#'),
        'name': m.module,
        'pascal': m.pascal,
        'description': m.spec.description!,
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

void _arbs(Out ctx, DbModel m) {
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

  const encoder = JsonEncoder.withIndent('  ');
  for (final locale in l10n.locales) {
    final template = locale == first;
    final entries = <String, Object?>{
      '@@locale': locale,
      for (final s in l10n.strings) ...{
        s.key: textOf(s, locale),
        if (template && (s.description != null || s.placeholders.isNotEmpty))
          '@${s.key}': {
            if (s.description != null) 'description': s.description,
            if (s.placeholders.isNotEmpty) 'placeholders': s.placeholders,
          },
      },
    };
    ctx.file(
      'lib/src/l10n/${m.module}_$locale.arb',
      '${encoder.convert(entries)}\n',
    );
  }
}
