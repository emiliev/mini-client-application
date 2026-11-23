import 'dart:io';

import 'package:mc_arch_check/mc_arch_check.dart';
import 'package:test/test.dart';

/// `dart test` runs in the package; Bazel runs in the runfiles root.
String _fixture(String name) {
  for (final base in const [
    'test/fixtures',
    'tool/mc_arch_check/test/fixtures',
    '_main/tool/mc_arch_check/test/fixtures',
  ]) {
    final dir = Directory('$base/$name');
    if (dir.existsSync()) {
      return dir.path;
    }
  }
  throw StateError('fixture $name not found from ${Directory.current.path}');
}

List<String> _check(String name) =>
    checkArchitecture(_fixture(name)).map((v) => v.toString()).toList();

void main() {
  test('T-0017-AC1 allowed edges produce no violation', () {
    expect(_check('ok'), isEmpty);
  });

  test('T-0017-AC1 feature importing another feature barrel fails, '
      'naming the feature → feature edge', () {
    final actual = _check('feature_to_feature');

    expect(actual, isNotEmpty);
    expect(
      actual,
      contains(
        allOf(
          contains('f_a imports package:f_b'),
          contains('feature → feature'),
        ),
      ),
    );
    expect(
      actual,
      contains(allOf(contains('f_a depends on f_b'), contains('pubspec.yaml'))),
    );
  });

  test('T-0017-AC1 utility importing a feature fails, '
      'naming the utility → feature edge', () {
    final actual = _check('utility_to_feature');

    expect(
      actual,
      contains(
        allOf(
          contains('u_a imports package:f_a'),
          contains('utility → feature'),
        ),
      ),
    );
  });

  test(
    'T-0017-AC2 package:x/src/ from another package fails as barrel-only',
    () {
      final actual = _check('src_import');

      expect(actual, hasLength(1));
      expect(actual.single, contains('barrel-only'));
      expect(actual.single, contains('package:u_base/src/u_base.dart'));
    },
  );

  test('T-0017-AC2 the same package importing its own src/ is allowed', () {
    // fixtures/ok/feature/f_a/test/own_usage.dart imports package:f_a/src/...
    expect(_check('ok'), isEmpty);
  });

  test('T-0017-AC4 a feature barrel exporting a page, bloc or DI initializer '
      'fails naming the symbol (R4)', () {
    final actual = _check('barrel_exports');

    expect(actual, hasLength(3));
    expect(actual, contains(allOf(contains('[R4]'), contains('CharsPage'))));
    expect(actual, contains(allOf(contains('[R4]'), contains('CharsBloc'))));
    expect(
      actual,
      contains(allOf(contains('[R4]'), contains('di_initializer.dart'))),
    );
    expect(actual.join(), isNot(contains('CharsFlow')));
    expect(actual.join(), isNot(contains('CharsEvent')));
  });

  test('T-0017-AC4 a route library importing a feature barrel fails (R15)', () {
    final actual = _check('route_imports_feature');

    expect(
      actual,
      contains(
        allOf(
          contains('[R15]'),
          contains('routes.dart'),
          contains('package:f_a'),
        ),
      ),
    );
  });

  test('T-0017-AC4 a RouteTargets method returning a non-Flow fails (R15)', () {
    final actual = _check('route_imports_feature');

    expect(actual, contains(contains('RouteTargets.page returns Widget')));
    expect(actual, contains(contains('RouteTargets.other returns CharsPage')));
    expect(actual.join(), isNot(contains('RouteTargets.a ')));
  });
}
