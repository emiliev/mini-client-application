// The app's side of the glue (plan 02 section 2.8, T-0074): its wiring list,
// its `*_wiring` pubspec deps and Bazel deps, and the root workspace members.

import 'package:mcgen/src/wire/groups.dart';

const appWiringsPath = 'app/mini_client/lib/src/wirings.dart';
const appPubspecPath = 'app/mini_client/pubspec.yaml';
const appWiringsBzlPath = 'app/mini_client/wirings.bzl';

/// The trees whose packages wire lists as workspace members; the root
/// pubspec's other members (spike/, third_party/, tool/) are kept as they are.
const _memberTrees = ['app/', 'feature/', 'utility/'];

/// `app/mini_client/lib/src/wirings.dart`: every group's DI initializer and
/// routes, in group order, and the catalogue's entries (unformatted).
String appWirings(GroupPlan plan) {
  final imports = {
    "import 'package:app_core/app_core.dart';",
    "import 'package:go_router/go_router.dart';",
    "import 'package:mc_di/mc_di.dart';",
    for (final g in plan.all)
      "import 'package:${g.package}/${g.package}.dart';",
  }.toList()..sort();
  return [
    wireHeader.trimRight(),
    '',
    ...imports,
    '',
    '/// Every wiring\'s DI initializer (navigator implementations), in group order.',
    'const List<McDIInitializer> wiringInitializers = [',
    for (final g in plan.all) '  ${g.initializer}(),',
    '];',
    '',
    '/// Every wiring\'s routes, in group order. `buildAppRouter` nests them under',
    '/// home (`nestUnderHome`, T-0049).',
    'List<RouteBase> get wiringRoutes => [',
    for (final g in plan.all) '  ...${g.routesGetter},',
    '];',
    '',
    '/// Every flow `mcgen wire` generated, for the `/catalogue` debug screen',
    '/// (T-0074): each opens from there. A flow wire could not route is',
    '/// listed with the reason, and does not open.',
    'const List<CatalogueEntry> catalogueEntries = [',
    for (final f in plan.flows)
      "  CatalogueEntry(module: '${f.module}', location: '${f.catalogueLocation}'),",
    for (final u in plan.unwired)
      "  CatalogueEntry(module: '${u.module}', note: ${dartString('not wired: ${u.reason}')}),",
    '];',
    '',
  ].join('\n');
}

/// [s] as a single-quoted Dart string literal.
String dartString(String s) {
  final b = StringBuffer("'");
  for (final c in s.split('')) {
    b.write(switch (c) {
      r'\' => r'\\',
      "'" => r"\'",
      r'$' => r'\$',
      _ => c,
    });
  }
  b.write("'");
  return '$b';
}

/// `app/mini_client/wirings.bzl`: the wiring packages the app depends on.
String appWiringsBzl(GroupPlan plan) {
  final labels = [for (final g in plan.all) '//${g.dir}']..sort();
  return [
    '"""The app\'s wiring packages (T-0074). Written by `mcgen wire`; never edit',
    'this file by hand."""',
    '',
    'WIRINGS = [',
    for (final l in labels) '    "$l",',
    ']',
    '',
  ].join('\n');
}

/// [pubspec] (the root one) with its `workspace:` members under app/,
/// feature/ and utility/ replaced by [dirs], sorted by code unit.
String workspaceMembers(String pubspec, List<String> dirs) {
  final lines = pubspec.split('\n');
  final start = lines.indexOf('workspace:');
  if (start < 0) throw StateError('pubspec.yaml has no "workspace:" block');
  var end = start + 1;
  final kept = <String>[];
  while (end < lines.length &&
      (lines[end].startsWith('  - ') || lines[end].startsWith('  #'))) {
    if (lines[end].startsWith('  #')) {
      throw StateError(
        'pubspec.yaml: a comment inside "workspace:" (line ${end + 1}); wire '
        'sorts the members, so put comments above the block',
      );
    }
    final m = lines[end].substring(4).trim();
    if (!_memberTrees.any(m.startsWith)) kept.add(m);
    end++;
  }
  final members = {
    ...kept,
    for (final d in dirs)
      if (_memberTrees.any(d.startsWith)) d,
  }.toList()..sort();
  return [
    ...lines.sublist(0, start + 1),
    for (final m in members) '  - $m',
    ...lines.sublist(end),
  ].join('\n');
}

/// [pubspec] (the app's) with its `*_wiring` dependencies replaced by the
/// groups', each `any`, in the block's sorted order.
String appWiringDeps(String pubspec, GroupPlan plan) {
  final lines = pubspec.split('\n');
  final start = lines.indexOf('dependencies:');
  if (start < 0) throw StateError('$appPubspecPath has no "dependencies:"');
  var end = start + 1;
  final entries = <(String, List<String>)>[];
  while (end < lines.length &&
      (lines[end].startsWith('  ') || lines[end].trim().isEmpty)) {
    if (lines[end].trim().isEmpty) break;
    if (lines[end].trim().startsWith('#')) {
      throw StateError(
        '$appPubspecPath: a comment inside "dependencies:" (line ${end + 1}); '
        'wire sorts the entries, so put comments above the block',
      );
    }
    if (!lines[end].startsWith('    ')) {
      final name = lines[end].trim().split(':').first;
      entries.add((name, [lines[end]]));
    } else {
      entries.last.$2.add(lines[end]);
    }
    end++;
  }
  final out = [
    for (final e in entries)
      if (!e.$1.endsWith('_wiring')) e,
    for (final g in plan.all) (g.package, ['  ${g.package}: any']),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    ...lines.sublist(0, start + 1),
    for (final e in out) ...e.$2,
    ...lines.sublist(end),
  ].join('\n');
}
