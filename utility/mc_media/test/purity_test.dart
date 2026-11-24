import 'dart:io';

import 'package:test/test.dart';

String get _base => Directory('utility/mc_media/lib').existsSync()
    ? 'utility/mc_media/lib'
    : 'lib';

void main() {
  test('T-0031-AC6 mc_media has one barrel and no McMediaScope', () {
    final top = [
      for (final e in Directory(_base).listSync())
        if (e is File) e.uri.pathSegments.last,
    ];
    expect(top, ['mc_media.dart']);
    final all = [
      for (final e in Directory(_base).listSync(recursive: true))
        if (e is File) e.path,
    ];
    expect(all.where((f) => f.contains('scope')), isEmpty);
  });

  test('T-0030-AC7 the pure mc_media library imports no Flutter', () {
    final base = _base;
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
