// T-0069-AC4, P-120 (d): spec lint rejects a module name whose ARB files
// gen-l10n reads as another locale (F-0066: `auth_sign_in_en.arb` reads as
// `id_EN`).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

/// The pinned Flutter SDK's gen-l10n source: `dart` runs from
/// `<flutter>/bin/cache/dart-sdk/bin/dart`.
String get _genL10nTypes {
  var dir = p.dirname(Platform.resolvedExecutable);
  for (var i = 0; i < 4; i++) {
    dir = p.dirname(dir);
  }
  return p.join(
    dir,
    'packages/flutter_tools/lib/src/localizations/gen_l10n_types.dart',
  );
}

const _spec = '''
schema: mcgen/1
module: NAME
tier: utility
archetype: utility_hello
ownership: managed
description: A test module.
l10n: {locales: [en, de]}
entities:
  - name: Note
    fields:
      - {name: text, type: String}
''';

List<String> _lint(String module) {
  final root = tempRoot('l10n-$module');
  addTearDown(() => root.deleteSync(recursive: true));
  writeFile(
    root,
    'utility/$module/mcgen.yaml',
    _spec.replaceAll('NAME', module),
  );
  final r = mcgen(['spec', 'lint', '--root', root.path, module]);
  return [
    for (final l in r.err.trim().split('\n'))
      if (l.contains('[l10n-name]')) l,
  ];
}

void main() {
  group('T-0069-AC4 P-120 (d) gen-l10n file-name locales', () {
    test('T-0069-AC4 the locale gen-l10n reads, as flutter_tools reads it', () {
      expect(genL10nFileLocale('characters_list_en'), 'en');
      expect(genL10nFileLocale('characters_list_en_XA'), 'en_XA');
      expect(genL10nFileLocale('mc_l10n_core_de'), 'de');
      // F-0066: `in` is Indonesian's deprecated code; intl replaces it.
      expect(genL10nFileLocale('auth_sign_in_en'), 'id_EN');
      expect(genL10nFileLocale('auth_signin_en'), 'en');
      expect(genL10nFileLocale('comics_de_tail_en'), 'de_Tail_EN');
      expect(genL10nFileLocale('nothing'), isNull);
    });

    test('T-0069-AC4 spec lint rejects auth_sign_in and passes auth_signin', () {
      expect(_lint('mc_sign_in'), [
        'utility/mc_sign_in/mcgen.yaml:2:9: error [l10n-name] module: gen-l10n '
            'reads mc_sign_in_de.arb as locale "id_DE", not "de" (F-0066): '
            'rename the module so no "_<segment>" after its first parses as a '
            'locale (e.g. auth_signin, not auth_sign_in)',
      ]);
      expect(_lint('mc_signin'), isEmpty);
    });

    test('T-0069-AC4 the ISO 639-1 set is the pinned SDK\'s, verbatim', () {
      final source = File(_genL10nTypes).readAsStringSync();
      final start = source.indexOf('final _iso639Languages = <String>{');
      expect(start, isNonNegative, reason: _genL10nTypes);
      final block = source.substring(start, source.indexOf('};', start));
      final sdk = [
        for (final m in RegExp("'([a-z]+)'").allMatches(block)) m[1]!,
      ];
      expect(iso639Languages.toList(), sdk);
    });
  });
}
