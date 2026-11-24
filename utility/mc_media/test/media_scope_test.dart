import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_media/mc_media.dart';

class _FakeResolver implements McImageResolver {
  @override
  bool canResolve(ApiImage image) => true;

  @override
  ResolvedImage resolve(ApiImage image) => throw UnimplementedError();
}

void main() {
  testWidgets('T-0030-AC6: of(context) returns the scope resolver', (
    tester,
  ) async {
    final resolver = _FakeResolver();
    McImageResolver? found;

    await tester.pumpWidget(
      McMediaScope(
        resolver: resolver,
        child: Builder(
          builder: (context) {
            found = McMediaScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found, same(resolver));
  });

  testWidgets('T-0030-AC6: of(context) without a scope throws FlutterError', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          McMediaScope.of(context);
          return const SizedBox();
        },
      ),
    );

    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('McMediaScope'));
  });

  testWidgets('T-0030-AC6: a new resolver rebuilds dependents only', (
    tester,
  ) async {
    final first = _FakeResolver();
    final second = _FakeResolver();
    final seen = <McImageResolver>[];
    final child = Builder(
      builder: (context) {
        seen.add(McMediaScope.of(context));
        return const SizedBox();
      },
    );

    await tester.pumpWidget(McMediaScope(resolver: first, child: child));
    await tester.pumpWidget(McMediaScope(resolver: first, child: child));
    await tester.pumpWidget(McMediaScope(resolver: second, child: child));

    expect(seen, [same(first), same(second)]);
  });
}
