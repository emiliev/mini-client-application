import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('T-0030-AC7 the pure mc_media library imports no Flutter', () {
    final base = Directory('utility/mc_media/lib').existsSync()
        ? 'utility/mc_media/lib'
        : 'lib';
    final files = [
      '$base/mc_media.dart',
      '$base/src/api_image.dart',
      '$base/src/image_resolver.dart',
    ];
    final flutterImport = RegExp(
      '(import|export)\\s+[\'"](package:flutter|dart:ui)',
    );
    final offenders = [
      for (final f in files)
        if (flutterImport.hasMatch(File(f).readAsStringSync())) f,
    ];
    expect(offenders, isEmpty);
  });
}
