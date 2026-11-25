import 'dart:io';

import 'package:test/test.dart';

Directory get _lib => Directory('utility/mc_media/lib').existsSync()
    ? Directory('utility/mc_media/lib')
    : Directory('lib');

/// Every Dart file under lib/. The BUILD target passes `glob(lib/**)` as
/// data, so the runfiles lib directory holds the whole library.
List<File> get _files => [
  for (final e in _lib.listSync(recursive: true, followLinks: true))
    if (e is File && e.path.endsWith('.dart')) e,
];

void main() {
  test('T-0031-AC6 mc_media has one barrel and no McMediaScope', () {
    final top = [
      for (final e in _lib.listSync())
        if (e is File) e.uri.pathSegments.last,
    ];
    expect(top, ['mc_media.dart']);
    expect(_files.where((f) => f.path.contains('scope')), isEmpty);
  });

  test(
    'T-0030-AC7 every file of the pure mc_media library imports no Flutter',
    () {
      final files = _files;
      expect(files.length, greaterThanOrEqualTo(3));
      final flutterImport = RegExp(
        '(import|export)\\s+[\'"](package:flutter|dart:ui)',
      );
      final offenders = [
        for (final f in files)
          if (flutterImport.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(offenders, isEmpty);
    },
  );
}
