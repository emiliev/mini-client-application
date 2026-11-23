import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

Widget _app(Widget child) => MaterialApp(
  theme: McTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('T-0019-AC1 buttons: each variant fires onPressed once', (
    tester,
  ) async {
    for (final v in McButtonVariant.values) {
      var taps = 0;
      await tester.pumpWidget(
        _app(McButton(label: 'Go', variant: v, onPressed: () => taps++)),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1, reason: v.name);
    }
  });

  testWidgets('T-0019-AC1 buttons: null onPressed disables the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const McButton(label: 'Go', onPressed: null)),
    );
    final b = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(b.enabled, isFalse);
  });

  testWidgets('T-0019-AC1 buttons: tap targets are at least 44x44', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            McButton(label: 'A', onPressed: () {}),
            McIconButton(
              icon: Icons.close,
              semanticLabel: 'Close',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    for (final t in [find.byType(FilledButton), find.byType(IconButton)]) {
      final s = tester.getSize(t);
      expect(s.width, greaterThanOrEqualTo(44));
      expect(s.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('T-0019-AC1 buttons: icon button exposes its semantic label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        McIconButton(
          icon: Icons.close,
          semanticLabel: 'Close',
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('T-0019-AC1 buttons: expand works in a Row without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Row(
          children: [McButton(label: 'Go', expand: true, onPressed: () {})],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Go'), findsOneWidget);
  });

  testWidgets('T-0019-AC2 buttons: one node has label, button flag and tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _app(
        McIconButton(
          icon: Icons.close,
          semanticLabel: 'Close',
          onPressed: () => taps++,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(McIconButton)),
      matchesSemantics(
        label: 'Close',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    await tester.tap(find.byType(McIconButton));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('T-0019-AC2 buttons: disabled icon button has no tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const McIconButton(
          icon: Icons.close,
          semanticLabel: 'Close',
          onPressed: null,
        ),
      ),
    );
    final data = tester
        .getSemantics(find.byType(McIconButton))
        .getSemanticsData();
    expect(data.label, 'Close');
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });
}
