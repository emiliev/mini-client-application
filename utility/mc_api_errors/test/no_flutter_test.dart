import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('T-0023-AC5 lib imports no Flutter', () {
    // `dart test` runs in the package; Bazel runs at the runfiles root.
    final lib = Directory('utility/mc_api_errors/lib').existsSync()
        ? Directory('utility/mc_api_errors/lib')
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
}
