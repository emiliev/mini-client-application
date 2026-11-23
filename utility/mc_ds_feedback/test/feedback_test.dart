import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

Widget _app(Widget child) => MaterialApp(
  theme: McTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('T-0019-AC2 Retry fires onRetry exactly once', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(McErrorView(message: 'Network down', onRetry: () => retries++)),
    );
    expect(retries, 0);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('T-0019-AC2 error view has a semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(McErrorView(message: 'Network down', onRetry: () {})),
    );
    expect(
      find.bySemanticsLabel('Error: Something went wrong. Network down'),
      findsOneWidget,
    );
    // The Retry button remains its own semantics node.
    expect(find.bySemanticsLabel('Retry'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('T-0019-AC2 custom retry label and title are honoured', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        McErrorView(
          title: 'Oops',
          message: 'm',
          retryLabel: 'Again',
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Oops'), findsOneWidget);
  });

  testWidgets('T-0019-AC1 loading shows a progress indicator with a label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const McLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('T-0019-AC1 empty view shows its message', (tester) async {
    await tester.pumpWidget(_app(const McEmptyView(message: 'No heroes')));
    expect(find.text('No heroes'), findsOneWidget);
  });
}
