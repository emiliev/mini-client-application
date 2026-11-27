import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('T-0052-AC5 lib imports no Flutter', () {
    // `dart test` runs in the package; Bazel runs at the runfiles root.
    final lib = Directory('utility/mc_feature_flags/lib').existsSync()
        ? Directory('utility/mc_feature_flags/lib')
        : Directory('lib');
    final dartFiles = lib
        .listSync(recursive: true, followLinks: true)
        .where((e) => FileSystemEntity.isFileSync(e.path))
        .where((e) => e.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty);
    final flutterImport = RegExp(
      '(import|export)\\s+[\'"](package:flutter|dart:ui)',
    );
    final offenders = [
      for (final f in dartFiles)
        if (flutterImport.hasMatch(File(f.path).readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('T-0052-AC5 the Flutter import detector sees a Flutter import '
      '(negative control)', () {
    final flutterImport = RegExp(
      '(import|export)\\s+[\'"](package:flutter|dart:ui)',
    );
    expect(
      flutterImport.hasMatch("import 'package:flutter/widgets.dart';"),
      isTrue,
    );
    expect(flutterImport.hasMatch("export 'dart:ui';"), isTrue);
    expect(flutterImport.hasMatch("import 'dart:io';"), isFalse);
  });
}
