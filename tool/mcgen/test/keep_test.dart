// T-0065-AC2 (keep regions): scanning, damage, the loc-compatible hash and
// splicing, at the unit level. gen_test.dart covers them end to end.

import 'package:mcgen/mcgen.dart';
import 'package:test/test.dart';

const _file = '''
void f() {
  // mcgen:keep a
  hand();
  // mcgen:end a
  gen();
  // mcgen:keep b
  // mcgen:end b
}
''';

void main() {
  group('T-0065-AC2 keep scan', () {
    test('T-0065-AC2 finds regions with their bodies', () {
      final s = KeepScan.of(_file, '//');
      expect(s.ok, isTrue);
      expect(s.ids, ['a', 'b']);
      expect(s['a']!.body, ['  hand();']);
      expect(s['b']!.body, isEmpty);
      expect([s['a']!.start, s['a']!.end], [1, 3]);
    });

    test('T-0065-AC2 reports each kind of damage with its line', () {
      expect(KeepScan.of('// mcgen:end x\n', '//').damage.map((d) => '$d'), [
        'line 1: end "x" without a keep',
      ]);
      expect(
        KeepScan.of(
          '// mcgen:keep x\n// mcgen:keep y\n// mcgen:end x\n',
          '//',
        ).damage.map((d) => '$d'),
        ['line 2: keep "y" opened inside keep "x" (line 1)'],
      );
      expect(
        KeepScan.of(
          '// mcgen:keep x\n// mcgen:end y\n',
          '//',
        ).damage.map((d) => '$d'),
        [
          'line 2: end "y" closes keep "x" (line 1)',
          'line 1: keep "x" is never closed',
        ],
      );
      expect(
        KeepScan.of(
          '// mcgen:keep x\n// mcgen:end x\n// mcgen:keep x\n// mcgen:end x\n',
          '//',
        ).damage.map((d) => '$d'),
        ['line 3: keep "x" appears twice'],
      );
      expect(KeepScan.of('  // mcgen:keep x\n', '//').damage.map((d) => '$d'), [
        'line 1: keep "x" is never closed',
      ]);
    });

    test('T-0065-AC2 yaml files use # markers; others have none', () {
      expect(keepPrefixFor('lib/a.dart'), '//');
      expect(keepPrefixFor('pubspec.yaml'), '#');
      expect(keepPrefixFor('lib/l10n/a_en.arb'), isNull);
      expect(
        KeepScan.of(
          'a: 1\n# mcgen:keep x\nb: 2\n# mcgen:end x\n',
          '#',
        )['x']!.body,
        ['b: 2'],
      );
    });
  });

  group('T-0065-AC2 the manifest hash ignores keep-region bodies only', () {
    test('T-0065-AC2 strip removes the lines strictly between the markers', () {
      expect(stripKeepRegions(_file, '//'), '''
void f() {
  // mcgen:keep a
  // mcgen:end a
  gen();
  // mcgen:keep b
  // mcgen:end b
}
''');
    });

    test(
      'T-0065-AC2 a body edit keeps the hash; an outside edit changes it',
      () {
        final h = contentHash('lib/x.dart', _file);
        expect(
          contentHash(
            'lib/x.dart',
            _file.replaceFirst('hand();', 'other();\n  more();'),
          ),
          h,
        );
        expect(
          contentHash('lib/x.dart', _file.replaceFirst('gen();', 'gen2();')),
          isNot(h),
        );
        // The hash is sha256 of the stripped text (tool/loc's rule, F-0065).
        expect(
          contentHash('a.json', '{}\n'),
          'ca3d163bab055381827226140568f3bef7eaac187cebd76878e0b63e9e442356',
        );
      },
    );
  });

  group('T-0065-AC2 splice', () {
    test('T-0065-AC2 carries old bodies into new output verbatim; new regions get defaults', () {
      const fresh =
          'void f() {\n  // mcgen:keep a\n  def();\n  // mcgen:end a\n  // mcgen:keep c\n  cdef();\n  // mcgen:end c\n}\n';
      const old =
          'void f() {\n  // mcgen:keep a\n      weird   ( );\n\n  // mcgen:end a\n}\n';
      final s = spliceKeepRegions(fresh, old, '//');
      expect(
        s.content,
        'void f() {\n  // mcgen:keep a\n      weird   ( );\n\n  // mcgen:end a\n  // mcgen:keep c\n  cdef();\n  // mcgen:end c\n}\n',
      );
      expect(s.kept, ['a']);
      expect(s.orphans, isEmpty);
    });

    test('T-0065-AC2 a region the output dropped is an orphan only if it holds code', () {
      const fresh = 'x\n';
      expect(
        spliceKeepRegions(
          fresh,
          '// mcgen:keep a\ncode\n// mcgen:end a\n',
          '//',
        ).orphans,
        ['a'],
      );
      expect(
        spliceKeepRegions(
          fresh,
          '// mcgen:keep a\n   \n// mcgen:end a\n',
          '//',
        ).orphans,
        isEmpty,
      );
    });
  });
}
