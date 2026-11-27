// The three painters of the quiz on a recording canvas (F-0059 fact 1),
// reached through the flow (no src/ import, R7): the countdown ring, the
// streak meter, and the results breakdown (the DS donut and bars). Each is
// taken from the widget tree and painted into a canvas that records calls.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/trivia_quiz_env.dart';

/// One recorded canvas call.
class _Call {
  _Call(this.name, this.args);

  final String name;
  final List<Object?> args;
}

/// A [Canvas] that records every call instead of drawing.
class _RecordingCanvas implements Canvas {
  final List<_Call> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(
      _Call(
        invocation.memberName.toString().replaceAllMapped(
          RegExp(r'Symbol\("(.*)"\)'),
          (m) => m.group(1)!,
        ),
        invocation.positionalArguments,
      ),
    );
    return null;
  }

  Iterable<_Call> named(String name) => calls.where((c) => c.name == name);
}

/// Paints the painter of the [CustomPaint] found by [finder] at its size.
_RecordingCanvas _paint(WidgetTester tester, Finder finder) {
  final paint = tester.widget<CustomPaint>(finder);
  final canvas = _RecordingCanvas();
  paint.painter!.paint(canvas, tester.getSize(finder));
  return canvas;
}

int _argb(Object? paint) => (paint! as Paint).color.toARGB32();

Future<void> _openRound(WidgetTester tester) async {
  currentSpec = (category: 'all', difficulty: 'easy', seed: 42);
  await currentRound(tester);
  await ensureTriviaContainer();
  await initFlow(
    tester,
    () => triviaTestHost(
      triviaFlowUnderTest(category: 'all', difficulty: 'easy', seed: 42),
    ),
  );
  await landAtOnce(tester);
}

void main() {
  setUpAll(bddSetUpAll);

  mcTestWidgets('T-0064-AC4 the countdown ring: a full turn at the start, '
      'the share left after 5 s, urgent at a quarter, no arc at the end', (
    tester,
  ) async {
    McTestSession.current.backend.useFixtureSet('trivia.default');
    await _openRound(tester);
    final palette = tester.element(find.byKey(countdownRingKey)).mcPalette;

    var canvas = _paint(tester, find.byKey(countdownRingKey));
    expect(canvas.named('drawCircle'), hasLength(1), reason: 'the track');
    expect(
      _argb(canvas.named('drawCircle').single.args[2]),
      palette.surfaceVariant.toARGB32(),
    );
    var arc = canvas.named('drawArc').single;
    expect(arc.args[1], -math.pi / 2, reason: 'from 12 o’clock');
    expect(arc.args[2] as double, closeTo(2 * math.pi, 1e-9));
    expect(_argb(arc.args[4]), palette.primary.toARGB32());

    await tester.pump(const Duration(milliseconds: 5000));
    canvas = _paint(tester, find.byKey(countdownRingKey));
    arc = canvas.named('drawArc').single;
    expect(arc.args[2] as double, closeTo(2 * math.pi * 0.75, 1e-9));
    expect(_argb(arc.args[4]), palette.primary.toARGB32());

    await tester.pump(const Duration(milliseconds: 10000));
    canvas = _paint(tester, find.byKey(countdownRingKey));
    arc = canvas.named('drawArc').single;
    expect(arc.args[2] as double, closeTo(2 * math.pi * 0.25, 1e-9));
    expect(_argb(arc.args[4]), palette.error.toARGB32(), reason: 'urgent');

    await tester.pump(const Duration(milliseconds: 5000));
    canvas = _paint(tester, find.byKey(countdownRingKey));
    expect(canvas.named('drawArc'), isEmpty, reason: 'no time left');
    expect(canvas.named('drawCircle'), hasLength(1));
  });

  mcTestWidgets('T-0064-AC4 the streak meter lights one pill per correct '
      'answer in a row, and none after a miss', (tester) async {
    McTestSession.current.backend.useFixtureSet('trivia.default');
    await _openRound(tester);
    final round = await currentRound(tester);
    final palette = tester.element(find.byKey(streakMeterKey)).mcPalette;
    List<int> pills() => [
      for (final c in _paint(tester, find.byKey(streakMeterKey)).named(
        'drawRRect',
      ))
        _argb(c.args[1]),
    ];
    final lit = palette.series2.toARGB32();
    final unlit = palette.surfaceVariant.toARGB32();

    expect(pills(), List.filled(10, unlit));
    for (final token in parseAnswerTokens('C0x3')) {
      await playQuestion(tester, round, token);
      await tapNext(tester);
    }
    expect(pills(), [...List.filled(3, lit), ...List.filled(7, unlit)]);
    final rects = [
      for (final c in _paint(tester, find.byKey(streakMeterKey)).named(
        'drawRRect',
      ))
        (c.args[0]! as RRect).outerRect,
    ];
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left, greaterThan(rects[i - 1].right), reason: 'gaps');
    }
    expect(
      rects.last.right,
      closeTo(tester.getSize(find.byKey(streakMeterKey)).width, 0.01),
    );

    await playQuestion(tester, round, (kind: 'W', elapsedMs: 0, hint: false));
    await tapNext(tester);
    expect(pills(), List.filled(10, unlit));
  });

  mcTestWidgets('T-0064-AC4 the results breakdown: one donut arc per '
      'outcome in proportion, and the points per question as bars', (
    tester,
  ) async {
    McTestSession.current.backend.useFixtureSet('trivia.default');
    await _openRound(tester);
    final round = await currentRound(tester);
    // 5 correct, 3 wrong, 2 timed out.
    for (final token in parseAnswerTokens('C0x5 W0x3 N0x2')) {
      await playQuestion(tester, round, token);
      await tapNext(tester);
    }
    await mcSettle(tester);

    final donut = tester.widget<McDonutChart>(find.byKey(breakdownDonutKey));
    expect([for (final d in donut.data) d.value], [5, 3, 2]);
    final donutPaint = find.descendant(
      of: find.byKey(breakdownDonutKey),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is McDonutPainter,
      ),
    );
    final arcs = [
      for (final c in _paint(tester, donutPaint).named('drawArc'))
        c.args[2]! as double,
    ];
    final sweeps = arcs.where((s) => s > 0.05).toList();
    expect(sweeps, hasLength(3), reason: 'one arc per outcome');
    final total = sweeps.fold<double>(0, (a, b) => a + b);
    expect(sweeps[0] / total, closeTo(0.5, 0.02));
    expect(sweeps[1] / total, closeTo(0.3, 0.02));
    expect(sweeps[2] / total, closeTo(0.2, 0.02));

    await tester.scrollUntilVisible(
      find.byKey(breakdownBarsKey),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(resultsBodyKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final bars = tester.widget<McBarChart>(find.byKey(breakdownBarsKey));
    expect(
      [for (final b in bars.data) b.label],
      [
        for (var i = 1; i <= 10; i++) '$i',
      ],
    );
    expect(
      [for (final b in bars.data) b.value],
      [
        150,
        175,
        200,
        225,
        250,
        0,
        0,
        0,
        0,
        0,
      ],
    );
    expect(
      [for (final b in bars.data) b.role],
      [
        ...List.filled(5, McChartRole.series1),
        ...List.filled(5, McChartRole.neutral),
      ],
    );
    final barPaint = find.descendant(
      of: find.byKey(breakdownBarsKey),
      matching: find.byType(CustomPaint),
    );
    final drawn = <Rect>[
      for (final finder in [
        for (var i = 0; i < barPaint.evaluate().length; i++) barPaint.at(i),
      ])
        for (final c in _paint(tester, finder).named('drawRect'))
          if ((c.args[1]! as Paint).style == PaintingStyle.fill)
            c.args[0]! as Rect,
    ];
    final heights = [for (final r in drawn) r.height]
      ..removeWhere((h) => h < 1);
    expect(heights, hasLength(greaterThanOrEqualTo(5)), reason: 'five bars');
  });
}
