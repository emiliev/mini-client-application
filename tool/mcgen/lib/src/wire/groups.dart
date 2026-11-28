// Wiring groups (plan 01 §3.4, §4.2): which exist, in which order the app
// lists them, and the packages `mcgen wire` generates for the groups whose
// features all come from specs (T-0074).
//
// A generated group is `app/wiring/<group>_wiring/`, every file wire-owned
// except the navigator implementations, which are written once and then
// belong to the engineer (plan 02 section 2.8). A feature of a hand-written
// group cannot be wired yet: its routes, targets and navigators are hand
// code (F-0074, P-127).

import 'dart:convert';
import 'dart:io';

import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:path/path.dart' as p;

/// The marker of a generated group (buildgen reads it).
const wireMarker = '.mcgen/wire.json';

/// The header of every Dart file wire writes (not owned ones).
const wireHeader =
    '// Written by `mcgen wire` from every spec and package (T-0074); never edit\n'
    '// it by hand. Regenerate it: `mcgen wire`.\n\n';

const generatedLocationsPath =
    'app/wiring/app_core/lib/src/locations/generated_locations.dart';

String pascal(String snake) => [
  for (final x in snake.split('_'))
    if (x.isNotEmpty) '${x[0].toUpperCase()}${x.substring(1)}',
].join();

String camel(String snake) {
  final s = pascal(snake);
  return '${s[0].toLowerCase()}${s.substring(1)}';
}

/// A flow wire routes: one generated feature.
class WiredFlow {
  WiredFlow(this.spec);

  final ModuleSpec spec;

  String get module => spec.module;
  String get flow => '${pascal(module)}Flow';
  String get route => '${pascal(module)}Route';
  String get navigator => spec.navigator!.name;
  String get target => camel(module);
  String get path => '/${module.replaceAll('_', '-')}';
  String get prefix => module;
}

/// One wiring group.
class WiringGroup {
  WiringGroup(this.name, {this.flows = const [], required this.generated});

  final String name;
  final List<WiredFlow> flows;

  /// Whether wire generates its package (else it is hand-written).
  final bool generated;

  String get package => '${name}_wiring';
  String get dir => 'app/wiring/$package';
  String get pascalName => pascal(name);
  String get routesGetter => '${camel(name)}Routes';
  String get initializer => '${pascalName}WiringDIInitializer';

  /// Root-relative path -> content (Dart unformatted). Generated groups only.
  final Map<String, String> files = {};

  /// Root-relative paths written once (navigator implementations).
  final Set<String> owned = {};
}

class GroupPlan {
  GroupPlan(this.all);

  /// Every group, in the app's order.
  final List<WiringGroup> all;

  Iterable<WiringGroup> get generated => all.where((g) => g.generated);
  Iterable<WiredFlow> get flows => [for (final g in generated) ...g.flows];
}

/// The groups under [root]: the hand-written `app/wiring/*_wiring` packages
/// and one generated group per domain of the specs wire routes. [order] is
/// `tool/mcgen/mcgen.yaml`'s `wire.groups`; [domains] maps a feature domain
/// (`feature/<domain>/`) to its group when the names differ.
GroupPlan planGroups(
  String root,
  RepoIndex index,
  List<ModuleSpec> specs, {
  List<String> order = const [],
  Map<String, String> domains = const {},
  Set<String> locations = const {},
}) {
  final hand = <String>{};
  for (final pkg in index.packages) {
    final m = RegExp(r'^app/wiring/([a-z0-9_]+)_wiring$').firstMatch(pkg.dir);
    if (m == null) continue;
    if (!File(p.join(root, pkg.dir, wireMarker)).existsSync()) {
      hand.add(m.group(1)!);
    }
  }
  final flows = <String, List<WiredFlow>>{};
  for (final s in specs) {
    if (s.tier != Tier.feature || s.ownership == Ownership.ejected) continue;
    if (s.archetype != 'list_detail') {
      throw StateError(
        '${s.file}: wire routes list_detail flows only so far, not '
        '"${s.archetype}" (P-127)',
      );
    }
    if (s.navigator == null) {
      throw StateError('${s.file}: a flow wire routes needs a navigator');
    }
    final parts = s.moduleDir.split('/');
    final domain = parts.length > 2 ? parts[1] : s.module;
    final group = domains[domain] ?? domain;
    if (hand.contains(group)) {
      throw StateError(
        '${s.file}: its group "$group" is hand-written '
        '(app/wiring/${group}_wiring); wire cannot add a generated flow to it '
        'yet (P-127)',
      );
    }
    (flows[group] ??= []).add(WiredFlow(s));
  }
  final names = {...hand, ...flows.keys};
  final ordered = [
    for (final g in order)
      if (names.contains(g)) g,
    ...(names.difference(order.toSet()).toList()..sort()),
  ];
  final groups = [
    for (final g in ordered)
      WiringGroup(
        g,
        flows: (flows[g] ?? [])..sort((a, b) => a.module.compareTo(b.module)),
        generated: !hand.contains(g),
      ),
  ];
  for (final g in groups.where((g) => g.generated)) {
    _emitGroup(root, g, locations);
  }
  return GroupPlan(groups);
}

/// The name of the `AppLocations` method an intent opens, when there is one
/// with a single `int` parameter (`openComic(ComicId)` -> `comic`).
String? _locationFor(String intent, Set<String> locations) {
  if (!intent.startsWith('open') || intent.length < 5) return null;
  final noun = '${intent[4].toLowerCase()}${intent.substring(5)}';
  return locations.contains(noun) ? noun : null;
}

/// The `AppLocations` methods that take one `int` id, from app_core's source.
Set<String> appLocationIdMethods(String root) {
  final f = File(
    p.join(root, 'app/wiring/app_core/lib/src/locations/app_locations.dart'),
  );
  if (!f.existsSync()) return const {};
  return {
    for (final m in RegExp(
      r'static String (\w+)\(int id\)',
    ).allMatches(f.readAsStringSync()))
      m.group(1)!,
  };
}

void _emitGroup(String root, WiringGroup g, Set<String> locations) {
  final pkg = g.package;
  final dir = g.dir;
  final flows = g.flows;
  String imp(WiredFlow f) =>
      "import 'package:${f.module}/${f.module}.dart' as ${f.prefix};";

  g.files['$dir/pubspec.yaml'] = [
    '# Written by `mcgen wire` (T-0074): the ${g.name} group\'s app layer, generated',
    '# from its features\' specs. Never edit it by hand.',
    'name: $pkg',
    'version: 0.1.0',
    'publish_to: none',
    'resolution: workspace',
    '',
    'environment:',
    '  sdk: ^3.13.0',
    '  flutter: ^3.47.7',
    '',
    'dependencies:',
    ...([
      '  app_core: any',
      for (final f in flows) '  ${f.module}: any',
      '  flutter:\n    sdk: flutter',
      '  get_it: ^8.0.0',
      '  go_router: 17.5.0',
      '  injectable: 3.0.0',
      '  mc_di: any',
    ]..sort()),
    '',
    'dev_dependencies:',
    '  flutter_test:',
    '    sdk: flutter',
    '  mc_analysis: any',
    '',
  ].join('\n');

  g.files['$dir/$wireMarker'] =
      '${const JsonEncoder.withIndent('  ').convert({
        'generator': 'mcgen wire',
        'group': g.name,
        'modules': [for (final f in flows) f.module],
        'owned': [for (final f in flows) 'lib/src/navigators/${f.module}_navigator_impl.dart'],
      })}\n';

  // The barrel.
  g.files['$dir/lib/$pkg.dart'] = [
    wireHeader.trimRight(),
    '',
    '// The ${g.name} group\'s app layer (plan 01 §3.4): typed routes, navigator',
    '// implementations and the DI initializer. Features never see any of it.',
    "import 'package:go_router/go_router.dart';",
    "import 'package:$pkg/src/routes/${g.name}_routes.dart';",
    '',
    "export 'package:$pkg/src/di/${pkg}_di_initializer.dart' show ${g.initializer};",
    "export 'package:$pkg/src/routes/${g.name}_routes.dart' show ${[for (final f in flows) f.route].join(', ')};",
    "export 'package:$pkg/src/routes/route_targets.dart' show ${g.pascalName}RouteTargets;",
    '',
    '/// The ${g.name} group\'s routes.',
    'List<RouteBase> get ${g.routesGetter} => <RouteBase>[...${camel(g.name)}TypedRoutes];',
    '',
  ].join('\n');

  // The typed routes: they import only the route targets (R15).
  g.files['$dir/lib/src/routes/${g.name}_routes.dart'] = [
    wireHeader.trimRight(),
    '',
    "import 'package:flutter/widgets.dart';",
    "import 'package:go_router/go_router.dart';",
    "import 'package:mc_di/mc_di.dart';",
    "import 'package:$pkg/src/routes/route_targets.dart';",
    '',
    "part '${g.name}_routes.g.dart';",
    '',
    '/// The ${g.name} group\'s typed routes (generated `\$appRoutes`). Each is',
    '/// absolute; the app nests them under home (`nestUnderHome`, F-0049).',
    'List<RouteBase> get ${camel(g.name)}TypedRoutes => \$appRoutes;',
    for (final f in flows) ...[
      '',
      '/// `${f.path}`: ${f.module}\'s flow. Its name is the screen analytics',
      '/// tracks (T-0053).',
      "@TypedGoRoute<${f.route}>(path: '${f.path}', name: '${f.module}')",
      'class ${f.route} extends GoRouteData with \$${f.route} {',
      '  const ${f.route}();',
      '',
      '  @override',
      '  Widget build(BuildContext context, GoRouterState state) =>',
      '      diContainer<${g.pascalName}RouteTargets>().${f.target}();',
      '}',
    ],
    '',
  ].join('\n');

  g.files['$dir/lib/src/routes/route_targets.dart'] = [
    wireHeader.trimRight(),
    '',
    for (final f in flows) imp(f),
    '',
    '/// What the typed routes build (R15): each member returns a feature\'s `*Flow`.',
    '/// `${g.pascalName}RouteTargetsImpl` (unannotated) supplies the navigators.',
    'abstract interface class ${g.pascalName}RouteTargets {',
    for (final f in flows) ...[
      '  /// ${f.module}: `${f.path}`.',
      '  ${f.prefix}.${f.flow} ${f.target}();',
    ],
    '}',
    '',
  ].join('\n');

  g.files['$dir/lib/src/routes/route_targets_impl.dart'] = [
    wireHeader.trimRight(),
    '',
    "import 'package:$pkg/src/routes/route_targets.dart';",
    for (final f in flows) imp(f),
    '',
    '/// Builds each route\'s flow from the feature barrels (R15: unannotated, so',
    '/// no generator reads it).',
    'class ${g.pascalName}RouteTargetsImpl implements ${g.pascalName}RouteTargets {',
    '  const ${g.pascalName}RouteTargetsImpl({',
    for (final f in flows) '    required ${f.prefix}.${f.navigator} ${f.target},',
    '  }) : ${[for (final f in flows) '_${f.target} = ${f.target}'].join(', ')};',
    '',
    for (final f in flows) '  final ${f.prefix}.${f.navigator} _${f.target};',
    for (final f in flows) ...[
      '',
      '  @override',
      '  ${f.prefix}.${f.flow} ${f.target}() =>',
      '      ${f.prefix}.${f.flow}(navigator: _${f.target});',
    ],
    '}',
    '',
  ].join('\n');

  g.files['$dir/lib/src/di/di_initializer.dart'] = [
    wireHeader.trimRight(),
    '',
    "import 'dart:async';",
    '',
    "import 'package:get_it/get_it.dart';",
    "import 'package:injectable/injectable.dart';",
    "import 'package:mc_di/mc_di.dart';",
    "import 'package:$pkg/src/di/di_initializer.config.dart';",
    '',
    '/// Registers the ${g.name} group\'s navigator implementations (injectable).',
    'class ${g.pascalName}NavigatorsDIInitializer extends McDIInitializer {',
    '  const ${g.pascalName}NavigatorsDIInitializer() : super(_init);',
    '}',
    '',
    '@InjectableInit()',
    'FutureOr<GetIt> _init(GetIt getIt, String? environment) =>',
    '    getIt.init(environment: environment);',
    '',
  ].join('\n');

  g.files['$dir/lib/src/di/${pkg}_di_initializer.dart'] = [
    wireHeader.trimRight(),
    '',
    "import 'dart:async';",
    '',
    "import 'package:get_it/get_it.dart';",
    "import 'package:mc_di/mc_di.dart';",
    "import 'package:$pkg/src/di/di_initializer.dart';",
    "import 'package:$pkg/src/routes/route_targets.dart';",
    "import 'package:$pkg/src/routes/route_targets_impl.dart';",
    for (final f in flows) imp(f),
    '',
    '/// The ${g.name} group\'s root registrations: the navigator implementations',
    '/// (injectable) and the route targets the typed routes resolve (R15).',
    '/// Needs a `GoRouter` in the root container (`RouterDIInitializer`) by the',
    '/// time a navigator is first used.',
    'class ${g.initializer} extends McDIInitializer {',
    '  const ${g.initializer}() : super(_init);',
    '',
    '  static FutureOr<void> _init(GetIt getIt, String? environment) async {',
    '    await const ${g.pascalName}NavigatorsDIInitializer().init(getIt);',
    '    getIt.registerLazySingleton<${g.pascalName}RouteTargets>(',
    '      () => ${g.pascalName}RouteTargetsImpl(',
    for (final f in flows) '        ${f.target}: getIt<${f.prefix}.${f.navigator}>(),',
    '      ),',
    '    );',
    '  }',
    '}',
    '',
  ].join('\n');

  for (final f in flows) {
    final rel = '$dir/lib/src/navigators/${f.module}_navigator_impl.dart';
    g.owned.add(rel);
    final methods = <String>[];
    var async = false;
    for (final o in f.spec.navigator!.outbound) {
      final args = [
        for (final (i, a) in o.args.indexed) '$a ${o.args.length == 1 ? 'id' : 'arg$i'}',
      ];
      final ret = o.returns == null ? 'void' : 'Future<${o.returns!.name}>';
      final loc = o.returns == null && o.args.length == 1
          ? _locationFor(o.name, locations)
          : null;
      methods.add('');
      methods.add('  @override');
      if (loc != null) {
        async = true;
        final value = o.args.single.endsWith('Id') ? 'id.value' : 'id';
        methods.addAll([
          '  $ret ${o.name}(${args.join(', ')}) {',
          '    unawaited(routerRef.router.push(AppLocations.$loc($value)));',
          '  }',
        ]);
      } else if (o.returns == null) {
        methods.addAll([
          '  $ret ${o.name}(${args.join(', ')}) {',
          '    // No location for this intent yet: this file is yours, map it here.',
          '  }',
        ]);
      } else {
        methods.addAll([
          '  $ret ${o.name}(${args.join(', ')}) =>',
          "      throw UnimplementedError('${f.navigator}.${o.name}: map it here');",
        ]);
      }
    }
    g.files[rel] = [
      '// Written once by `mcgen wire` (T-0074); from then on this file is yours',
      '// (plan 02 section 2.8): map each intent of the feature to a location.',
      '',
      if (async) "import 'dart:async';",
      if (async) '',
      "import 'package:app_core/app_core.dart';",
      "import 'package:injectable/injectable.dart';",
      "import 'package:${f.module}/${f.module}.dart';",
      '',
      '/// ${f.module}\'s way out of the feature: its intents become routes. It',
      '/// asks [routerRef] for the live router at each call.',
      '@LazySingleton(as: ${f.navigator})',
      'class ${f.navigator}Impl implements ${f.navigator} {',
      '  ${f.navigator}Impl(this.routerRef);',
      '',
      '  final RouterRef routerRef;',
      ...methods,
      '}',
      '',
    ].join('\n');
  }

  g.files['$dir/test/routes_test.dart'] = [
    wireHeader.trimRight(),
    '',
    "import 'package:app_core/app_core.dart';",
    "import 'package:flutter_test/flutter_test.dart';",
    "import 'package:$pkg/$pkg.dart';",
    "import 'package:go_router/go_router.dart';",
    '',
    'void main() {',
    "  test('every GeneratedLocations entry of the ${g.name} group equals its typed route', () {",
    for (final f in flows)
      '    expect(GeneratedLocations.${f.target}, const ${f.route}().location);',
    '  });',
    '',
    "  test('every route of the ${g.name} group is named and absolute', () {",
    '    final routes = ${g.routesGetter}.whereType<GoRoute>().toList();',
    '    expect(routes.map((r) => r.name).toList(), [',
    for (final f in flows) "      '${f.module}',",
    '    ]);',
    "    expect(routes.every((r) => r.path.startsWith('/')), isTrue);",
    '  });',
    '}',
    '',
  ].join('\n');
}

/// `app_core`'s `GeneratedLocations`: one location per generated flow.
String generatedLocations(GroupPlan plan) => [
  wireHeader.trimRight(),
  '',
  '/// Typed locations of the flows `mcgen wire` generated (plan 01 §4.2,',
  '/// T-0074), for navigation across groups and for the catalogue. Each equals',
  '/// its typed route\'s `location`, which the generated group\'s',
  '/// `test/routes_test.dart` checks. The hand-written groups\' locations are',
  '/// `AppLocations`.',
  'abstract final class GeneratedLocations {',
  for (final g in plan.generated)
    for (final f in g.flows) ...[
      '  /// ${f.module}\'s flow, in ${g.package}.',
      "  static const String ${f.target} = '${f.path}';",
      '',
    ],
  '}',
  '',
].join('\n').replaceAll('\n\n}', '\n}');
