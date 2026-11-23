import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/main.dart';
import 'package:hello/src/counter_state.dart';

void main() {
  testWidgets('T-0014-AC2 hello app renders and counts under Bazel', (tester) async {
    await tester.pumpWidget(HelloApp());
    expect(find.text('Hello, mini-client'), findsOneWidget);
    expect(find.text('Tap + to start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('T-0014-AC6 state.when / maybeWhen / map on a private-case union', (tester) async {
    await tester.pumpWidget(HelloApp());
    expect(find.text('initial'), findsOneWidget);
    await tester.tap(find.byKey(const Key('increment')));
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(find.text('Count: 2'), findsOneWidget);
    expect(find.text('counting'), findsOneWidget);

    const failed = CounterState.failed(reason: 'x');
    expect(failed.when(initial: () => '', counting: (_) => '', failed: (r) => r), 'x');
    expect(kindOf(failed), 'failed');
    expect(increment(failed), const CounterState.counting(1));
  });

  testWidgets('T-0014-AC7 generated \$appRoutes navigates to the typed DetailRoute', (tester) async {
    await tester.pumpWidget(HelloApp());
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open_detail')));
    await tester.pumpAndSettle();
    expect(find.text('Detail for 1'), findsOneWidget);
  });
}
