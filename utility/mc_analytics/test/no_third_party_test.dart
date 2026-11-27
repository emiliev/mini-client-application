import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('T-0053-AC3 lib imports no network client and no third-party SDK '
      '(P-004)', () {
    // `flutter test` runs in the package; Bazel runs at the runfiles root.
    final lib = Directory('utility/mc_analytics/lib').existsSync()
        ? Directory('utility/mc_analytics/lib')
        : Directory('lib');
    final dartFiles = lib
        .listSync(recursive: true, followLinks: true)
        .where((e) => FileSystemEntity.isFileSync(e.path))
        .where((e) => e.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty);
    final importLine = RegExp(r'''^(?:import|export)\s+['"]([^'"]+)['"]''');
    const allowedPackages = {
      'flutter',
      'get_it',
      'mc_analytics',
      'mc_config',
      'mc_di',
      'mc_monitoring',
      'mc_storage',
    };
    const allowedDart = {
      'dart:async',
      'dart:collection',
      'dart:math',
    };
    final offenders = <String>[];
    for (final f in dartFiles) {
      for (final line in File(f.path).readAsLinesSync()) {
        final m = importLine.firstMatch(line);
        if (m == null) {
          continue;
        }
        final uri = m.group(1)!;
        final ok = uri.startsWith('dart:')
            ? allowedDart.contains(uri)
            : uri.startsWith('package:') &&
                  allowedPackages.contains(uri.substring(8).split('/').first);
        if (!ok) {
          offenders.add('${f.path}: $uri');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('T-0053-AC3 the scan sees an import that is not allowed (control)', () {
    // The same regex over a line that must be flagged.
    final importLine = RegExp(r'''^(?:import|export)\s+['"]([^'"]+)['"]''');

    expect(
      importLine.firstMatch("import 'package:dio/dio.dart';")!.group(1),
      'package:dio/dio.dart',
    );
    expect(
      importLine.firstMatch("import 'dart:io';")!.group(1),
      'dart:io',
    );
  });
}
