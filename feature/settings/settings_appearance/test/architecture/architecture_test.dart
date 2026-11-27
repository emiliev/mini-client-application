// Conformance of the package's shape (plan 01 §3.3), not a test of feature
// behaviour: R4 (the barrel) and R15 (generators read Flutter-free files).
import 'dart:io';

import 'package:test/test.dart';

/// Bazel only (`pure_srcs.txt` is a genrule output): the test runs at the
/// runfiles root, where the package sits at its workspace path.
String _path(String rel) => 'feature/settings/settings_appearance/$rel';

/// One export directive, in either quote style, with an optional `show`.
final RegExp _export = RegExp(
  r'''export\s+(['"])([^'"]+)\1\s*(show\s+([^;]+))?;''',
  multiLine: true,
);

/// Any export directive at all, to check [_export] understood each one.
final RegExp _anyExport = RegExp(r'^\s*export\b', multiLine: true);

/// A Flutter import or export, in either quote style.
final RegExp _flutter = RegExp(
  r'''(import|export)\s+['"](package:flutter[a-z_]*/|dart:ui)''',
);

List<String> _pureSrcs() =>
    File(_path('test/architecture/pure_srcs.txt'))
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

void main() {
  test('T-0063-AC7 the barrel exports only the flow and the navigator, each '
      'with show', () {
    final barrel = File(_path('lib/settings_appearance.dart'))
        .readAsStringSync();
    final exports = _export.allMatches(barrel).toList();

    expect(exports, isNotEmpty);
    expect(
      exports,
      hasLength(_anyExport.allMatches(barrel).length),
      reason: 'every export directive is one this check understands',
    );
    final shown = <String>{};
    for (final e in exports) {
      expect(
        e.group(3),
        isNotNull,
        reason: '${e.group(2)} exports without show',
      );
      shown.addAll(e.group(4)!.split(',').map((s) => s.trim()));
      expect(e.group(2), startsWith('package:settings_appearance/src/'));
    }
    expect(shown, {'SettingsAppearanceFlow', 'SettingsAppearanceNavigator'});
    expect(
      RegExp(r'^library\b', multiLine: true).hasMatch(barrel),
      isFalse,
      reason: 'no library directive',
    );
  });

  test('T-0063-AC7 every file a generator reads imports no Flutter (R15)', () {
    final files = _pureSrcs();
    expect(files, hasLength(greaterThanOrEqualTo(7)));
    for (final f in files) {
      final source = File(_path(f)).readAsStringSync();
      expect(_flutter.hasMatch(source), isFalse, reason: '$f imports Flutter');
    }
  });

  test('T-0063-AC7 the feature reaches the preferences only through '
      'mc_appearance: no API, no Dio, no session of its own', () {
    final lib = Directory(_path('lib'));
    final offenders = [
      for (final f in lib.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            RegExp(
              r'''import\s+['"]package:(dio|retrofit|mc_api_client|mc_session)/''',
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('T-0063-AC7 the checks read both quote styles (controls)', () {
    expect(_flutter.hasMatch('import "package:flutter/widgets.dart";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter/widgets.dart';"), isTrue);
    expect(_flutter.hasMatch('export "dart:ui";'), isTrue);
    expect(_flutter.hasMatch("import 'package:flutter_bloc/x.dart';"), isTrue);
    expect(_flutter.hasMatch("import 'package:freezed/x.dart';"), isFalse);

    final e = _export.firstMatch('export "package:x/src/a.dart" show A, B;')!;
    expect(e.group(2), 'package:x/src/a.dart');
    expect(e.group(4), 'A, B');
    expect(_export.hasMatch('export "package:x/a.dart\';'), isFalse);
  });
}
