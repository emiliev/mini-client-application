// T-0069-AC4, P-120 (b): the shared kit-symbol table lists only names the
// kits' barrels really export.

import 'package:mcgen/mcgen.dart';
import 'package:mcgen/src/emit/common/barrel_scan.dart';
import 'package:mcgen/src/emit/common/kit_symbols.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

void main() {
  group('T-0069-AC4 P-120 (b) the kit-symbol table', () {
    for (final MapEntry(key: uri, value: names)
        in firstPartyKitSymbols.entries) {
      test('T-0069-AC4 $uri exports every name the table lists', () {
        final file = firstPartyLibraryFile(uri, repoRoot);
        expect(file, isNotNull, reason: '$uri is a first-party library');
        final exported = exportedNames(file!, repoRoot);
        expect(
          names.where((n) => !exported.contains(n)).toList(),
          isEmpty,
          reason: 'names the table lists but $uri does not export',
        );
      });
    }

    test('T-0069-AC4 the scan finds what a barrel shows and hides', () {
      final root = tempRoot('barrels');
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(
        root,
        'utility/mc_k/lib/mc_k.dart',
        "export 'src/a.dart';\n"
            "export 'package:mc_k/src/b.dart' show B1;\n"
            "export 'src/c.dart' hide C2;\n",
      );
      writeFile(
        root,
        'utility/mc_k/lib/src/a.dart',
        '// class NotThis {}\n'
            'abstract final class A1 {}\n'
            'class _Private {}\n'
            'extension AExt on int {}\n'
            'const int aConst = 1;\n'
            'Future<void> aFunction(int x) async {}\n'
            'typedef AFn = void Function();\n',
      );
      writeFile(
        root,
        'utility/mc_k/lib/src/b.dart',
        'class B1 {}\nclass B2 {}\n',
      );
      writeFile(
        root,
        'utility/mc_k/lib/src/c.dart',
        'class C1 {}\nclass C2 {}\n',
      );
      final names = exportedNames(
        p.join(root.path, 'utility/mc_k/lib/mc_k.dart'),
        root.path,
      );
      expect(names, {'A1', 'AExt', 'aConst', 'aFunction', 'AFn', 'B1', 'C1'});
    });

    test('T-0069-AC4 registerKitSymbols resolves a kit name to its barrel', () {
      final table = SymbolTable();
      registerKitSymbols(table);
      expect(
        table.resolve(const SymbolRef('McBloc')),
        'package:mc_bloc_kit/mc_bloc_kit.dart',
      );
      expect(
        table.resolve(const SymbolRef('ReadContext')),
        'package:flutter_bloc/flutter_bloc.dart',
      );
    });
  });
}
