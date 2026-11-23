import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('T-0022-AC7 lib imports no Flutter and declares no mixins', () {
    // `dart test` runs in the package; Bazel runs at the runfiles root.
    final lib = Directory('utility/mc_bloc_kit/lib').existsSync()
        ? Directory('utility/mc_bloc_kit/lib')
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
    final mixin = RegExp(r'^\s*(base\s+)?mixin\b', multiLine: true);
    final offenders = [
      for (final f in dartFiles)
        if (flutterImport.hasMatch(File(f.path).readAsStringSync()) ||
            mixin.hasMatch(File(f.path).readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
