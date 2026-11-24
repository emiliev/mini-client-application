import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'T-0030-AC7 every file of the pure mc_media library imports no Flutter',
    () {
      // The BUILD target passes exactly the pure files as data, so the lib
      // directory in the runfiles holds the whole pure library.
      final lib = Directory('utility/mc_media/lib').existsSync()
          ? Directory('utility/mc_media/lib')
          : Directory('lib');
      final files = lib
          .listSync(recursive: true, followLinks: true)
          .where((e) => FileSystemEntity.isFileSync(e.path))
          .where((e) => e.path.endsWith('.dart'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(3));
      final flutterImport = RegExp(
        '(import|export)\\s+[\'"](package:flutter|dart:ui)',
      );
      final offenders = [
        for (final f in files)
          if (flutterImport.hasMatch(File(f.path).readAsStringSync())) f.path,
      ];
      expect(offenders, isEmpty);
    },
  );
}
