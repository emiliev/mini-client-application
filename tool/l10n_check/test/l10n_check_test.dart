import 'dart:io';

import 'package:l10n_check/l10n_check.dart';
import 'package:test/test.dart';

/// Writes `<root>/utility/<pkg>/lib/src/l10n/<pkg>_<locale>.arb` files.
String _workspace(Map<String, Map<String, Map<String, String>>> packages) {
  final root = Directory.systemTemp.createTempSync('l10n_check_').path;
  for (final pkg in packages.entries) {
    final dir = Directory('$root/utility/${pkg.key}/lib/src/l10n')
      ..createSync(recursive: true);
    for (final locale in pkg.value.entries) {
      final body = {
        '@@locale': locale.key,
        ...locale.value,
      }.entries.map((e) => '"${e.key}": "${e.value}"').join(',');
      File('${dir.path}/${pkg.key}_${locale.key}.arb')
          .writeAsStringSync('{$body}');
    }
  }
  addTearDown(() => Directory(root).deleteSync(recursive: true));
  return root;
}

void main() {
  test('T-0025-AC3 a complete ARB set passes', () {
    final root = _workspace({
      'mc_a': {
        'en': {'hello': 'Hello'},
        'de': {'hello': 'Hallo'},
      },
    });
    expect(checkL10n(root), isEmpty);
  });

  test('T-0025-AC3 a missing locale fails naming the locale', () {
    final root = _workspace({
      'mc_a': {
        'en': {'hello': 'Hello'},
      },
    });
    final violations = checkL10n(root);
    expect(violations, hasLength(1));
    expect(violations.single, contains('mc_a'));
    expect(violations.single, contains('missing locale de'));
  });

  test('T-0025-AC3 a missing key fails naming the locale and key', () {
    final root = _workspace({
      'mc_a': {
        'en': {'hello': 'Hello', 'bye': 'Bye'},
        'de': {'hello': 'Hallo'},
      },
    });
    final violations = checkL10n(root);
    expect(violations, ['mc_a: locale de is missing key bye']);
  });

  test('T-0025-AC3 an unknown key and a pseudo-locale gap are reported', () {
    final root = _workspace({
      'mc_a': {
        'en': {'hello': 'Hello'},
        'de': {'hello': 'Hallo', 'extra': 'x'},
        'en_XA': <String, String>{},
      },
    });
    expect(
      checkL10n(root),
      containsAll([
        'mc_a: locale de has unknown key extra',
        'mc_a: locale en_XA is missing key hello',
      ]),
    );
  });
}
