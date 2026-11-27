// mcgen's global settings (`tool/mcgen/mcgen.yaml`) and where the tool's own
// files are (bricks, schema).

import 'dart:io';
import 'dart:isolate';

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The generator version written into every manifest.
const mcgenVersion = '0.1.0';

class McgenConfig {
  const McgenConfig({
    required this.globalSeed,
    required this.languageVersion,
    required this.sdkConstraint,
    required this.formatterVersion,
    this.pageWidth = 80,
    this.thirdParty = const {},
    this.sdkPackages = const {},
  });

  factory McgenConfig.parse(String text, String file) {
    final y = loadYaml(text);
    Never bad(String why) => throw McgenException.message(file, 'config', why);
    if (y is! YamlMap) bad('not a YAML map');
    T need<T>(YamlMap m, String key) {
      final v = m[key];
      if (v is! T) bad('"$key" must be a ${T.toString()}');
      return v;
    }

    final dart = need<YamlMap>(y, 'dart');
    final packages = y['third_party'];
    final sdk = y['sdk_packages'];
    return McgenConfig(
      globalSeed: need<int>(y, 'global_seed'),
      languageVersion: '${need<Object>(dart, 'language_version')}',
      sdkConstraint: need<String>(dart, 'sdk_constraint'),
      formatterVersion: '${need<Object>(dart, 'formatter_version')}',
      pageWidth: (dart['page_width'] as int?) ?? 80,
      thirdParty: packages is YamlMap
          ? {for (final e in packages.entries) '${e.key}': '${e.value}'}
          : const {},
      sdkPackages: sdk is YamlList ? {for (final s in sdk) '$s'} : const {},
    );
  }

  /// `globalSeed` of plan 02 section 2.5.
  final int globalSeed;

  /// The language version generated code is formatted for (`3.13`).
  final String languageVersion;

  /// The `environment: sdk:` constraint generated pubspecs carry.
  final String sdkConstraint;

  /// The pinned SDK's `dart format --version`; mcgen refuses any other.
  final String formatterVersion;
  final int pageWidth;

  /// Third-party package -> pubspec constraint, for packages emitters use.
  final Map<String, String> thirdParty;

  /// Packages that come from the Flutter SDK (`flutter: {sdk: flutter}`).
  final Set<String> sdkPackages;
}

/// tool/mcgen itself: bricks, schema and config.
class ToolLayout {
  const ToolLayout(this.dir, {String? bricksDir}) : _bricksDir = bricksDir;

  /// The package directory of the running mcgen.
  factory ToolLayout.current({String? bricksDir}) {
    final lib = Isolate.resolvePackageUriSync(
      Uri.parse('package:mcgen/mcgen.dart'),
    );
    if (lib == null) {
      throw StateError(
        'cannot resolve package:mcgen; run with `fvm dart run tool/mcgen`',
      );
    }
    return ToolLayout(
      p.dirname(p.dirname(lib.toFilePath())),
      bricksDir: bricksDir,
    );
  }

  final String dir;
  final String? _bricksDir;

  String get bricksDir => _bricksDir ?? p.join(dir, 'bricks');
  String get schemaPath => p.join(dir, 'schema', 'mcgen-1.json');
  String get configPath => p.join(dir, 'mcgen.yaml');

  McgenConfig loadConfig() => McgenConfig.parse(
    File(configPath).readAsStringSync(),
    'tool/mcgen/mcgen.yaml',
  );
}
