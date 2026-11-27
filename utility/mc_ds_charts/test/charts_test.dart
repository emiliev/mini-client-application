// T-0059-AC1 (no overflow), AC3 (robustness), AC4 (semantics and theming) and
// the animation behaviour of the chart widgets.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

import 'support/recording_canvas.dart';

const _empty = 'Nothing to chart yet.';

// One ThemeData per variant: McThemeExtension has no value equality, so a fresh
// ThemeData on every pump would start AnimatedTheme's 200 ms lerp.
final _themes = {
  for (final v in McThemeVariant.values)
    v: McTheme.of(v).copyWith(platform: TargetPlatform.iOS),
};

Widget _app(
  Widget child, {
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
  bool disableAnimations = false,
  double? width = 375,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _themes[variant],
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: disableAnimations,
        highContrast:
            variant == McThemeVariant.highContrast ||
            variant == McThemeVariant.highContrastDark,
      ),
      child: app!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: width == null ? child : SizedBox(width: width, child: child),
      ),
    ),
  );
}

/// A [width] x [height] logical surface at 2x, reset after the test.
void mcSetSurface(WidgetTester tester, double width, double height) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width * 2, height * 2);
  addTearDown(tester.view.reset);
}

CustomPainter _painterOf(WidgetTester tester, Type chart) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(chart), matching: find.byType(CustomPaint)),
  );
  return paint.painter!;
}

RecordingCanvas _paintNow(WidgetTester tester, Type chart) {
  final c = RecordingCanvas();
  final size = tester.getSize(
    find.descendant(of: find.byType(chart), matching: find.byType(CustomPaint)),
  );
  _painterOf(tester, chart).paint(c, size);
  return c;
}

const _bars = [
  McBarDatum(label: 'Mon', value: 4),
  McBarDatum(label: 'Tue', value: 7),
  McBarDatum(label: 'Wed', value: 2),
];

McBarChart _barChart(List<McBarDatum> data, {bool animate = false}) =>
    McBarChart(
      data: data,
      semanticLabel: 'Quiz scores per day',
      emptyMessage: _empty,
      animate: animate,
    );

McDonutChart _donutChart(List<McDonutSegment> data, {bool animate = false}) =>
    McDonutChart(
      data: data,
      semanticLabel: 'Answers by result',
      emptyMessage: _empty,
      centerLabel: '12',
      centerCaption: 'answers',
      animate: animate,
    );

const _segments = [
  McDonutSegment(label: 'Right', value: 8),
  McDonutSegment(label: 'Wrong', value: 3),
  McDonutSegment(label: 'Skipped', value: 1),
];

McLineChart _lineChart(
  List<McLineSeries> series, {
  List<String> x = const ['Q1', 'Q2', 'Q3'],
  bool animate = false,
}) => McLineChart(
  xLabels: x,
  series: series,
  semanticLabel: 'Readers per quarter',
  emptyMessage: _empty,
  animate: animate,
);

const _lines = [
  McLineSeries(label: 'Print', values: [3, 5, 4]),
  McLineSeries(label: 'Digital', values: [1, 2, 6]),
];

McRadarChart _radarChart(
  List<McRadarSeries> series, {
  List<String> axes = const ['Speed', 'Power', 'Brains', 'Luck'],
  bool animate = false,
}) => McRadarChart(
  axes: axes,
  series: series,
  semanticLabel: 'Hero stats',
  emptyMessage: _empty,
  animate: animate,
);

const _radar = [
  McRadarSeries(label: 'Hulk', values: [0.4, 1, 0.3, 0.2]),
  McRadarSeries(label: 'Stark', values: [0.5, 0.6, 1, 0.9]),
];

const _events = [
  McTimelineEvent(date: '1962', title: 'First issue', description: 'It begins'),
  McTimelineEvent(
    date: '1984',
    title: 'Secret Wars',
    role: McChartRole.negative,
  ),
  McTimelineEvent(
    date: '2008',
    title: 'Iron Man',
    description: 'The film',
    role: McChartRole.positive,
  ),
];

McTimeline _timeline(List<McTimelineEvent> events) => McTimeline(
  events: events,
  semanticLabel: 'Publication history',
  emptyMessage: _empty,
);

/// Labels of the semantics nodes in accessibility traversal order.
List<String> _traversal(WidgetTester tester) => [
  for (final n in tester.semantics.simulatedAccessibilityTraversal()) n.label,
];

void main() {
  tearDown(McChartValidation.reset);

  group('T-0059-AC3 empty data shows the empty state', () {
    final cases = <String, Widget Function()>{
      'bar': () => _barChart(const []),
      'donut': () => _donutChart(const []),
      'line (no labels)': () => _lineChart(const [
        McLineSeries(label: 'A', values: []),
      ], x: const []),
      'line (no series)': () => _lineChart(const []),
      'line (series without values)': () => _lineChart(const [
        McLineSeries(label: 'A', values: []),
      ]),
      'radar (no series)': () => _radarChart(const []),
      'radar (no axes)': () => _radarChart(const [
        McRadarSeries(label: 'A', values: []),
      ], axes: const []),
      'timeline': () => _timeline(const []),
    };
    for (final e in cases.entries) {
      testWidgets('T-0059-AC3 ${e.key}', (tester) async {
        await tester.pumpWidget(_app(e.value()));
        expect(find.byType(McEmptyView), findsOneWidget);
        expect(find.text(_empty), findsOneWidget);
        expect(find.text('Nothing here yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('T-0059-AC3 the empty title is the callers', (tester) async {
      await tester.pumpWidget(
        _app(
          const McBarChart(
            data: [],
            semanticLabel: 's',
            emptyMessage: 'm',
            emptyTitle: 'Keine Daten',
          ),
        ),
      );
      expect(find.text('Keine Daten'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
    });

    testWidgets('T-0059-AC3 data arriving replaces the empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_barChart(const [])));
      expect(find.byType(McEmptyView), findsOneWidget);
      await tester.pumpWidget(_app(_barChart(_bars)));
      expect(find.byType(McEmptyView), findsNothing);
      expect(_painterOf(tester, McBarChart), isA<McBarPainter>());
    });
  });

  group('T-0059-AC3 NaN and infinite values', () {
    final bad = <String, Widget Function(double)>{
      'bar': (v) => _barChart([
        const McBarDatum(label: 'a', value: 1),
        McBarDatum(label: 'b', value: v),
      ]),
      'donut': (v) => _donutChart([
        const McDonutSegment(label: 'a', value: 1),
        McDonutSegment(label: 'b', value: v),
      ]),
      'line': (v) => _lineChart([
        McLineSeries(label: 'a', values: [1, v, 2]),
      ]),
      'radar': (v) => _radarChart([
        McRadarSeries(label: 'a', values: [1, v, 0.5, 0.2]),
      ]),
    };
    for (final e in bad.entries) {
      for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
        testWidgets('T-0059-AC3 debug: ${e.key} with $v is an ArgumentError', (
          tester,
        ) async {
          await tester.pumpWidget(_app(e.value(v)));
          expect(tester.takeException(), isA<ArgumentError>());
        });
      }
    }

    testWidgets(
      'T-0059-AC3 debug: a negative donut value is an ArgumentError',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(_donutChart(const [McDonutSegment(label: 'a', value: -1)])),
        );
        expect(tester.takeException(), isA<ArgumentError>());
      },
    );

    testWidgets('T-0059-AC3 debug: the message names the chart', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_barChart(const [McBarDatum(label: 'a', value: double.nan)])),
      );
      final e = tester.takeException() as ArgumentError;
      expect(e.message, contains('McBarChart'));
      expect(e.message, contains('1 values'));
    });

    group('release path (injected flag)', () {
      late List<FlutterErrorDetails> reports;
      setUp(() {
        reports = [];
        McChartValidation.releaseModeOverride = true;
        McChartValidation.reporterOverride = reports.add;
      });

      testWidgets(
        'T-0059-AC3 release: bars skip the bad value and report once',
        (
          tester,
        ) async {
          final data = [
            const McBarDatum(label: 'a', value: 1),
            const McBarDatum(label: 'b', value: double.nan),
            const McBarDatum(label: 'c', value: double.infinity),
            const McBarDatum(label: 'd', value: 3),
          ];
          await tester.pumpWidget(_app(_barChart(data)));
          expect(tester.takeException(), isNull);
          expect(reports, hasLength(1));
          expect(reports.single.library, 'mc_ds_charts');
          expect(reports.single.exception.toString(), contains('2 values'));
          expect(reports.single.exception.toString(), contains('Skipped'));
          final painter = _painterOf(tester, McBarChart) as McBarPainter;
          expect(painter.data.map((d) => d.label), ['a', 'd']);
          expect(_paintNow(tester, McBarChart).fillRects(), hasLength(2));
          // the same data again, and rebuilds: still one report
          await tester.pumpWidget(_app(_barChart([...data])));
          await tester.pump();
          expect(reports, hasLength(1));
          // new bad data: a new report
          await tester.pumpWidget(
            _app(
              _barChart([
                ...data,
                const McBarDatum(label: 'e', value: double.nan),
              ]),
            ),
          );
          expect(reports, hasLength(2));
        },
      );

      testWidgets('T-0059-AC3 release: a donut skips bad and negative values', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            _donutChart(const [
              McDonutSegment(label: 'a', value: 1),
              McDonutSegment(label: 'b', value: double.nan),
              McDonutSegment(label: 'c', value: -4),
              McDonutSegment(label: 'd', value: 1),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(reports, hasLength(1));
        final p = _painterOf(tester, McDonutChart) as McDonutPainter;
        expect(p.data.map((d) => d.label), ['a', 'd']);
        expect(_paintNow(tester, McDonutChart).arcs(), hasLength(2));
      });

      testWidgets('T-0059-AC3 release: a line draws a gap and reports once', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            _lineChart(const [
              McLineSeries(label: 'a', values: [1, double.nan, 3]),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(reports, hasLength(1));
        expect(
          _paintNow(tester, McLineChart).named('drawCircle'),
          hasLength(2),
        );
      });

      testWidgets('T-0059-AC3 release: a radar draws a bad value as 0', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            _radarChart(const [
              McRadarSeries(label: 'a', values: [1, double.nan, 0.5, 0.2]),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(reports, hasLength(1));
        final p = _painterOf(tester, McRadarChart) as McRadarPainter;
        final f = p.frame(tester.getSize(find.byType(CustomPaint).first));
        expect(
          p.polygonOf(0, tester.getSize(find.byType(CustomPaint).first))[1],
          f.center,
        );
      });

      testWidgets('T-0059-AC3 release: only bad values leave the empty state', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(_barChart(const [McBarDatum(label: 'a', value: double.nan)])),
        );
        expect(find.byType(McEmptyView), findsOneWidget);
        expect(reports, hasLength(1));
      });

      testWidgets('T-0059-AC3 release: a line of only NaN is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            _lineChart(const [
              McLineSeries(
                label: 'a',
                values: [double.nan, double.nan, double.nan],
              ),
            ]),
          ),
        );
        expect(find.byType(McEmptyView), findsOneWidget);
      });

      testWidgets(
        'T-0059-AC3 release: unsupported shapes are reported, not thrown',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(
              _lineChart([
                for (var i = 0; i < 4; i++)
                  McLineSeries(label: 'S$i', values: const [1, 2, 3]),
              ]),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(reports, hasLength(1));
          expect(
            (_painterOf(tester, McLineChart) as McLinePainter).series,
            hasLength(3),
          );
          reports.clear();
          await tester.pumpWidget(
            _app(
              _radarChart(
                [
                  for (var i = 0; i < 3; i++)
                    McRadarSeries(label: 'S$i', values: const [1, 1]),
                ],
                axes: const ['A', 'B'],
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(reports.length, greaterThanOrEqualTo(2));
          expect(
            (_painterOf(tester, McRadarChart) as McRadarPainter).series,
            hasLength(2),
          );
        },
      );

      test('T-0059-AC3 the default reporter is FlutterError.reportError', () {
        McChartValidation.reporterOverride = null;
        final seen = <FlutterErrorDetails>[];
        final old = FlutterError.onError;
        FlutterError.onError = seen.add;
        addTearDown(() => FlutterError.onError = old);
        McChartValidation.sanitize<double>(
          [1, double.nan],
          (v) => v.isFinite,
          chart: 'X',
          what: 'values',
        );
        expect(seen, hasLength(1));
        expect(McChartValidation.isRelease, isTrue);
      });
    });

    test('T-0059-AC3 the mode follows kReleaseMode unless injected', () {
      expect(McChartValidation.isRelease, kReleaseMode);
      McChartValidation.releaseModeOverride = true;
      expect(McChartValidation.isRelease, isTrue);
      McChartValidation.releaseModeOverride = false;
      expect(McChartValidation.isRelease, isFalse);
    });

    test('T-0059-AC3 sanitize returns the same list when all is well', () {
      final list = [1.0, 2.0];
      expect(
        identical(
          McChartValidation.sanitize<double>(
            list,
            (v) => v.isFinite,
            chart: 'X',
            what: 'v',
          ),
          list,
        ),
        isTrue,
      );
    });

    test('T-0059-AC3 check returns true when fine and never reports', () {
      final reports = <FlutterErrorDetails>[];
      McChartValidation.reporterOverride = reports.add;
      expect(McChartValidation.check(true, 'x'), isTrue);
      expect(reports, isEmpty);
      McChartValidation.releaseModeOverride = true;
      expect(McChartValidation.check(false, 'x'), isFalse);
      expect(reports, hasLength(1));
      McChartValidation.releaseModeOverride = false;
      expect(() => McChartValidation.check(false, 'x'), throwsArgumentError);
    });
  });

  group('T-0059-AC3 unsupported shapes throw in debug', () {
    testWidgets('T-0059-AC3 more than three line series', (tester) async {
      await tester.pumpWidget(
        _app(
          _lineChart([
            for (var i = 0; i < 4; i++)
              McLineSeries(label: 'S$i', values: const [1, 2, 3]),
          ]),
        ),
      );
      expect(tester.takeException(), isA<ArgumentError>());
    });

    testWidgets('T-0059-AC3 a line series longer than its labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _lineChart(const [
            McLineSeries(label: 'a', values: [1, 2, 3, 4]),
          ]),
        ),
      );
      expect(tester.takeException(), isA<ArgumentError>());
    });

    for (final axes in [2, 9]) {
      testWidgets('T-0059-AC3 a radar with $axes axes', (tester) async {
        await tester.pumpWidget(
          _app(
            _radarChart(
              [McRadarSeries(label: 'a', values: List.filled(axes, 0.5))],
              axes: List.generate(axes, (i) => 'A$i'),
            ),
          ),
        );
        expect(tester.takeException(), isA<ArgumentError>());
      });
    }

    testWidgets('T-0059-AC3 a radar with three series', (tester) async {
      await tester.pumpWidget(
        _app(
          _radarChart([
            for (var i = 0; i < 3; i++)
              McRadarSeries(label: 'S$i', values: const [1, 1, 1, 1]),
          ]),
        ),
      );
      expect(tester.takeException(), isA<ArgumentError>());
    });

    testWidgets('T-0059-AC3 a radar series of the wrong length', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _radarChart(const [
            McRadarSeries(label: 'a', values: [1, 1]),
          ]),
        ),
      );
      expect(tester.takeException(), isA<ArgumentError>());
    });

    testWidgets(
      'T-0059-AC3 three to eight axes and one or two series are fine',
      (
        tester,
      ) async {
        for (final n in [3, 8]) {
          await tester.pumpWidget(
            _app(
              _radarChart(
                [McRadarSeries(label: 'a', values: List.filled(n, 0.5))],
                axes: List.generate(n, (i) => 'A$i'),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('T-0059-AC3 degenerate but valid data', () {
    testWidgets('T-0059-AC3 all-zero bars (both orientations)', (tester) async {
      for (final o in Axis.values) {
        await tester.pumpWidget(
          _app(
            McBarChart(
              data: const [
                McBarDatum(label: 'a', value: 0),
                McBarDatum(label: 'b', value: 0),
              ],
              semanticLabel: 's',
              emptyMessage: _empty,
              orientation: o,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final rec = _paintNow(tester, McBarChart);
        expect(rec.fillRects(), isEmpty);
        for (final l in rec.lines()) {
          expect(l.$1.dx.isFinite && l.$1.dy.isFinite, isTrue);
        }
      }
    });

    testWidgets('T-0059-AC3 a single bar, positive and negative', (
      tester,
    ) async {
      for (final v in [5.0, -5.0, 0.0]) {
        await tester.pumpWidget(
          _app(_barChart([McBarDatum(label: 'a', value: v)])),
        );
        expect(tester.takeException(), isNull);
        expect(
          _paintNow(tester, McBarChart).fillRects(),
          hasLength(v == 0 ? 0 : 1),
        );
      }
    });

    testWidgets('T-0059-AC3 all-zero donut shows an empty ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _donutChart(const [
            McDonutSegment(label: 'a', value: 0),
            McDonutSegment(label: 'b', value: 0),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_paintNow(tester, McDonutChart).arcs(), hasLength(1));
    });

    testWidgets('T-0059-AC3 a single donut segment', (tester) async {
      await tester.pumpWidget(
        _app(_donutChart(const [McDonutSegment(label: 'a', value: 9)])),
      );
      expect(tester.takeException(), isNull);
      expect(_paintNow(tester, McDonutChart).arcs(), hasLength(1));
    });

    testWidgets('T-0059-AC3 constant, single-point and all-zero lines', (
      tester,
    ) async {
      for (final (values, x) in [
        ([4.0, 4.0, 4.0], ['a', 'b', 'c']),
        ([4.0], ['a']),
        ([0.0, 0.0], ['a', 'b']),
      ]) {
        await tester.pumpWidget(
          _app(_lineChart([McLineSeries(label: 'a', values: values)], x: x)),
        );
        expect(tester.takeException(), isNull);
        expect(
          _paintNow(tester, McLineChart).named('drawCircle'),
          hasLength(values.length),
        );
      }
    });

    testWidgets('T-0059-AC3 an all-zero and a single-axis-value radar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _radarChart(const [
            McRadarSeries(label: 'a', values: [0, 0, 0, 0]),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _app(
          _radarChart(const [
            McRadarSeries(label: 'a', values: [1, 0, 0, 0]),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0059-AC3 a single timeline event', (tester) async {
      await tester.pumpWidget(_app(_timeline(const [_event1])));
      expect(tester.takeException(), isNull);
      expect(find.text('First issue'), findsOneWidget);
    });
  });

  group('T-0059-AC4 semantics', () {
    testWidgets('T-0059-AC4 bar chart: summary first, then each bar in order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_barChart(_bars)));
      expect(find.bySemanticsLabel('Quiz scores per day'), findsOneWidget);
      expect(
        _traversal(tester).where((l) => l.isNotEmpty).toList(),
        ['Quiz scores per day', 'Mon: 4', 'Tue: 7', 'Wed: 2'],
      );
      handle.dispose();
    });

    testWidgets('T-0059-AC4 horizontal bars keep the data order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          McBarChart(
            data: _bars,
            semanticLabel: 'Scores',
            emptyMessage: _empty,
            orientation: Axis.horizontal,
            valueFormatter: (v) => '${v.toInt()} pts',
          ),
        ),
      );
      expect(_traversal(tester).where((l) => l.isNotEmpty).toList(), [
        'Scores',
        'Mon: 4 pts',
        'Tue: 7 pts',
        'Wed: 2 pts',
      ]);
      handle.dispose();
    });

    testWidgets('T-0059-AC4 many bars: every bar has a node, in order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _barChart([
            for (var i = 0; i < 30; i++)
              McBarDatum(label: 'Bar $i', value: i.toDouble()),
          ]),
        ),
      );
      final labels = _traversal(tester)
          .where((l) => l.startsWith('Bar '))
          .toList();
      expect(labels, [for (var i = 0; i < 30; i++) 'Bar $i: $i']);
      handle.dispose();
    });

    testWidgets('T-0059-AC4 the data order wins over the visual order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _barChart(const [
            McBarDatum(label: 'Zed', value: 9),
            McBarDatum(label: 'Alpha', value: 1),
            McBarDatum(label: 'Mid', value: 5),
          ]),
        ),
      );
      expect(
        _traversal(tester).where((l) => l.contains(':')).toList(),
        ['Zed: 9', 'Alpha: 1', 'Mid: 5'],
      );
      handle.dispose();
    });

    testWidgets(
      'T-0059-AC4 donut: summary, then segments; legend and centre hidden',
      (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(_donutChart(_segments)));
        final labels = _traversal(tester).where((l) => l.isNotEmpty).toList();
        expect(labels, [
          'Answers by result',
          'Right: 8',
          'Wrong: 3',
          'Skipped: 1',
        ]);
        expect(
          find.text('Right 8'),
          findsOneWidget,
          reason: 'the legend is drawn',
        );
        expect(find.bySemanticsLabel('Right 8'), findsNothing);
        expect(find.text('12'), findsOneWidget);
        expect(find.bySemanticsLabel('12'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('T-0059-AC4 line chart: one node per series, legend hidden', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_lineChart(_lines)));
      expect(_traversal(tester).where((l) => l.isNotEmpty).toList(), [
        'Readers per quarter',
        'Print: Q1 3, Q2 5, Q3 4',
        'Digital: Q1 1, Q2 2, Q3 6',
      ]);
      expect(find.text('Digital'), findsOneWidget);
      expect(find.bySemanticsLabel('Digital'), findsNothing);
      handle.dispose();
    });

    testWidgets('T-0059-AC4 radar: one node per series', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_radarChart(_radar)));
      expect(_traversal(tester).where((l) => l.isNotEmpty).toList(), [
        'Hero stats',
        'Hulk: Speed 0.4, Power 1, Brains 0.3, Luck 0.2',
        'Stark: Speed 0.5, Power 0.6, Brains 1, Luck 0.9',
      ]);
      handle.dispose();
    });

    testWidgets('T-0059-AC4 timeline: summary then events in order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_timeline(_events)));
      expect(_traversal(tester).where((l) => l.isNotEmpty).toList(), [
        'Publication history',
        '1962. First issue. It begins',
        '1984. Secret Wars',
        '2008. Iron Man. The film',
      ]);
      expect(find.bySemanticsLabel('First issue'), findsNothing);
      handle.dispose();
    });

    testWidgets('T-0059-AC4 painted output is not read as text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_barChart(_bars)));
      final all = _traversal(tester);
      // axis ticks and category labels are painted, never nodes of their own
      for (final tick in ['0', '5', '10']) {
        expect(all, isNot(contains(tick)));
      }
      expect(all, isNot(contains('Mon')));
      handle.dispose();
    });

    testWidgets('T-0059-AC4 the caller formats values', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          McDonutChart(
            data: _segments,
            semanticLabel: 'Ergebnis',
            emptyMessage: _empty,
            valueFormatter: (v) => '${v.toInt()} Prozent',
          ),
        ),
      );
      expect(_traversal(tester), contains('Right: 8 Prozent'));
      handle.dispose();
    });

    for (final variant in McThemeVariant.values) {
      group('meetsGuideline in ${variant.name}', () {
        final widgets = <String, Widget>{
          'bar': _barChart(_bars),
          'bar highlighted': McBarChart(
            data: _bars,
            semanticLabel: 's',
            emptyMessage: _empty,
            highlightIndex: 1,
          ),
          'bar negative': _barChart(const [
            McBarDatum(label: 'a', value: -3, role: McChartRole.negative),
            McBarDatum(label: 'b', value: 4, role: McChartRole.positive),
          ]),
          'donut': _donutChart(_segments),
          'line': _lineChart(_lines),
          'radar': _radarChart(_radar),
          'timeline': _timeline(_events),
          'empty': _barChart(const []),
        };
        for (final e in widgets.entries) {
          testWidgets('T-0059-AC4 ${e.key}', (tester) async {
            final handle = tester.ensureSemantics();
            await tester.pumpWidget(_app(e.value, variant: variant));
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            handle.dispose();
          });
        }
      });
    }

    testWidgets(
      'T-0059-AC4 every drawn series and role colour is 3:1 on the surface',
      (
        tester,
      ) async {
        double ratio(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          return (la > lb ? la + 0.05 : lb + 0.05) /
              (la > lb ? lb + 0.05 : la + 0.05);
        }

        for (final variant in McThemeVariant.values) {
          final p = McPalette.of(variant);
          await tester.pumpWidget(
            _app(
              _barChart([
                for (final (i, r) in McChartRole.values.indexed)
                  McBarDatum(label: 'r$i', value: i + 1.0, role: r),
              ]),
              variant: variant,
            ),
          );
          await tester.pumpAndSettle();
          final fills = _paintNow(tester, McBarChart).filledRects();
          expect(fills, hasLength(McChartRole.values.length));
          for (final f in fills) {
            expect(
              ratio(f.$2, p.surface),
              greaterThanOrEqualTo(3),
              reason: '${variant.name} ${f.$2}',
            );
          }
          await tester.pumpWidget(
            _app(_donutChart(_segments), variant: variant),
          );
          await tester.pumpAndSettle();
          for (final a in _paintNow(tester, McDonutChart).arcs()) {
            expect(ratio(a.$4.color, p.surface), greaterThanOrEqualTo(3));
          }
        }
      },
    );
  });

  group('T-0059-AC1 layout at large text', () {
    final wide = <String, Widget Function()>{
      'bar': () => _barChart(const [
        McBarDatum(label: 'Durchschnittsgeschwindigkeit', value: 4),
        McBarDatum(label: 'Höchstgeschwindigkeit', value: 7),
        McBarDatum(label: 'Zeit', value: 2),
      ]),
      'bar horizontal': () => McBarChart(
        data: const [
          McBarDatum(label: 'Durchschnittsgeschwindigkeit', value: 4),
          McBarDatum(label: 'Höchstgeschwindigkeit', value: -7),
        ],
        semanticLabel: 's',
        emptyMessage: _empty,
        orientation: Axis.horizontal,
      ),
      'bar 30': () => _barChart([
        for (var i = 0; i < 30; i++)
          McBarDatum(label: 'Donaudampfschifffahrt $i', value: (i % 7) - 2.0),
      ]),
      'donut': () => _donutChart(const [
        McDonutSegment(label: 'Richtige Antworten insgesamt', value: 800),
        McDonutSegment(label: 'Falsche Antworten insgesamt', value: 1),
        McDonutSegment(label: 'Übersprungene Fragen', value: 2),
      ]),
      'line': () => _lineChart(
        const [
          McLineSeries(label: 'Gedruckte Ausgaben', values: [3, 5, 4]),
          McLineSeries(label: 'Digitale Ausgaben', values: [1, 2, 6]),
          McLineSeries(label: 'Hörbücher und mehr', values: [0, 1, 1]),
        ],
        x: const ['Erstes Quartal', 'Zweites Quartal', 'Drittes Quartal'],
      ),
      'radar': () => _radarChart(
        const [
          McRadarSeries(
            label: 'Gedruckte Ausgaben',
            values: [0.4, 0.5, 0.6, 0.7, 0.8],
          ),
          McRadarSeries(
            label: 'Digitale Ausgaben',
            values: [0.9, 0.5, 0.2, 0.7, 0.1],
          ),
        ],
        axes: const [
          'Geschwindigkeit',
          'Kraft',
          'Intelligenz',
          'Durchhaltevermögen',
          'Glück',
        ],
      ),
      'timeline': () => _timeline(const [
        McTimelineEvent(
          date: 'Neunzehnhundertzweiundsechzig',
          title: 'Veröffentlichungsgeschichte der Ausgabe',
          description: 'Donaudampfschifffahrtsgesellschaftskapitän',
        ),
        _event1,
      ]),
    };
    for (final e in wide.entries) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('T-0059-AC1 ${e.key} at ${scale}x has no overflow', (
          tester,
        ) async {
          mcSetSurface(tester, 375, 2400);
          await tester.pumpWidget(
            _app(SingleChildScrollView(child: e.value()), scale: scale),
          );
          expect(tester.takeException(), isNull);
          final size = tester.getSize(find.byType(SingleChildScrollView));
          expect(size.width, lessThanOrEqualTo(375));
        });
      }
    }

    testWidgets('T-0059-AC1 a 3x probe on a narrow column', (tester) async {
      mcSetSurface(tester, 280, 3000);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: Column(
              children: [
                _barChart(_bars),
                _donutChart(_segments),
                _lineChart(_lines),
                _radarChart(_radar),
                _timeline(_events),
              ],
            ),
          ),
          scale: 3,
          width: 280,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0059-AC1 an unbounded width falls back to a default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _barChart(_bars),
          ),
          width: null,
        ),
      );
      expect(
        tester.getSize(find.byType(CustomPaint).last).width,
        mcChartUnboundedWidth,
      );
    });

    testWidgets('T-0059-AC1 the donut shrinks to a narrow parent', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_donutChart(_segments), width: 120));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CustomPaint).last).width, 120);
    });

    testWidgets('T-0059-AC1 a horizontal chart grows with its bars', (
      tester,
    ) async {
      Future<double> heightOf(int n) async {
        await tester.pumpWidget(
          _app(
            McBarChart(
              data: [
                for (var i = 0; i < n; i++)
                  McBarDatum(label: 'b$i', value: i + 1.0),
              ],
              semanticLabel: 's',
              emptyMessage: _empty,
              orientation: Axis.horizontal,
            ),
          ),
        );
        return tester.getSize(find.byType(CustomPaint).last).height;
      }

      expect(await heightOf(8), greaterThan(await heightOf(2)));
    });

    testWidgets('T-0059-AC1 a vertical chart takes the height asked for', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          McBarChart(
            data: _bars,
            semanticLabel: 's',
            emptyMessage: _empty,
            height: 123,
          ),
        ),
      );
      expect(tester.getSize(find.byType(CustomPaint).last).height, 123);
    });
  });

  group('T-0059-AC3 legends and updates', () {
    testWidgets('T-0059-AC3 a single line series has no legend; two do', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_lineChart([_lines.first])));
      expect(find.text('Print'), findsNothing);
      await tester.pumpWidget(_app(_lineChart(_lines)));
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Digital'), findsOneWidget);
    });

    testWidgets('T-0059-AC3 the donut legend can be turned off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          McDonutChart(
            data: _segments,
            semanticLabel: 's',
            emptyMessage: _empty,
            showLegend: false,
          ),
        ),
      );
      expect(find.text('Right 8'), findsNothing);
    });

    testWidgets('T-0059-AC3 a radar with two series has a legend', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_radarChart(_radar)));
      expect(find.text('Hulk'), findsOneWidget);
      await tester.pumpWidget(_app(_radarChart([_radar.first])));
      expect(find.text('Hulk'), findsNothing);
    });

    testWidgets('T-0059-AC3 new data reaches the painter', (tester) async {
      await tester.pumpWidget(_app(_barChart(_bars)));
      expect((_painterOf(tester, McBarChart) as McBarPainter).data, _bars);
      await tester.pumpWidget(
        _app(_barChart(const [McBarDatum(label: 'x', value: 1)])),
      );
      expect(
        (_painterOf(tester, McBarChart) as McBarPainter).data,
        hasLength(1),
      );
    });

    testWidgets('T-0059-AC3 the min sweep of the donut is the callers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          McDonutChart(
            data: const [
              McDonutSegment(label: 'a', value: 1000),
              McDonutSegment(label: 'b', value: 1),
            ],
            semanticLabel: 's',
            emptyMessage: _empty,
            minSweepDegrees: 20,
          ),
        ),
      );
      final p = _painterOf(tester, McDonutChart) as McDonutPainter;
      expect(p.minSweep, closeTo(20 * 3.141592653589793 / 180, 1e-12));
      expect(p.sweeps[1], closeTo(p.minSweep, 1e-12));
    });

    test('T-0059-AC3 value classes compare by value', () {
      expect(
        const McBarDatum(label: 'a', value: 1),
        const McBarDatum(label: 'a', value: 1),
      );
      expect(
        const McBarDatum(label: 'a', value: 1) ==
            const McBarDatum(label: 'a', value: 2),
        isFalse,
      );
      expect(
        const McBarDatum(label: 'a', value: 1) ==
            const McBarDatum(label: 'b', value: 1),
        isFalse,
      );
      expect(
        const McBarDatum(label: 'a', value: 1) ==
            const McBarDatum(label: 'a', value: 1, role: McChartRole.negative),
        isFalse,
      );
      expect(
        const McBarDatum(label: 'a', value: double.nan),
        const McBarDatum(label: 'a', value: double.nan),
      );
      expect(
        const McBarDatum(label: 'a', value: 1).hashCode,
        const McBarDatum(label: 'a', value: 1).hashCode,
      );
      expect(
        const McDonutSegment(label: 'a', value: 1),
        const McDonutSegment(label: 'a', value: 1),
      );
      expect(
        const McDonutSegment(label: 'a', value: 1) ==
            const McDonutSegment(label: 'a', value: 2),
        isFalse,
      );
      expect(
        const McDonutSegment(label: 'a', value: double.nan),
        const McDonutSegment(label: 'a', value: double.nan),
      );
      expect(
        const McDonutSegment(label: 'a', value: 1).hashCode,
        const McDonutSegment(label: 'a', value: 1).hashCode,
      );
      expect(
        const McLineSeries(label: 'a', values: [1, 2]),
        const McLineSeries(label: 'a', values: [1, 2]),
      );
      expect(
        const McLineSeries(label: 'a', values: [1, 2]) ==
            const McLineSeries(label: 'a', values: [1, 3]),
        isFalse,
      );
      expect(
        const McLineSeries(label: 'a', values: [1, 2]).hashCode,
        const McLineSeries(label: 'a', values: [1, 2]).hashCode,
      );
      expect(
        const McRadarSeries(label: 'a', values: [1, 2]),
        const McRadarSeries(label: 'a', values: [1, 2]),
      );
      expect(
        const McRadarSeries(label: 'a', values: [1, 2]) ==
            const McRadarSeries(label: 'b', values: [1, 2]),
        isFalse,
      );
      expect(
        const McRadarSeries(label: 'a', values: [1, 2]).hashCode,
        const McRadarSeries(label: 'a', values: [1, 2]).hashCode,
      );
      expect(
        _events.first,
        const McTimelineEvent(
          date: '1962',
          title: 'First issue',
          description: 'It begins',
        ),
      );
      expect(_events.first == _events[1], isFalse);
      expect(
        _events.first.hashCode,
        const McTimelineEvent(
          date: '1962',
          title: 'First issue',
          description: 'It begins',
        ).hashCode,
      );
    });
  });

  group('T-0059-AC3 timeline layout', () {
    testWidgets('T-0059-AC3 events run top to bottom in the given order', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_timeline(_events)));
      final ys = [
        for (final t in ['First issue', 'Secret Wars', 'Iron Man'])
          tester.getTopLeft(find.text(t)).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      expect(find.text('It begins'), findsOneWidget);
      expect(find.text('1984'), findsOneWidget);
    });

    testWidgets('T-0059-AC3 rails fill the row, only the ends are trimmed', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_timeline(_events)));
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<McTimelineRailPainter>()
          .toList();
      expect(painters, hasLength(3));
      expect(painters.map((p) => p.isFirst), [true, false, false]);
      expect(painters.map((p) => p.isLast), [false, false, true]);
    });

    testWidgets('T-0059-AC3 it scrolls inside the callers scroll view', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 200);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: _timeline([
              for (var i = 0; i < 20; i++)
                McTimelineEvent(date: '$i', title: 'Event $i'),
            ]),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0059-AC3 marker colours come from the roles', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_timeline(_events)));
      final p = McPalette.light;
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((x) => x.painter)
          .whereType<McTimelineRailPainter>()
          .toList();
      expect(painters[0].markerColor, p.series1);
      expect(painters[1].markerColor, p.error);
      expect(painters[2].markerColor, p.success);
      expect(painters[0].ringColor, p.surface);
      expect(painters[0].lineColor, p.outline);
    });
  });

  group('T-0059-AC5 animation', () {
    testWidgets('T-0059-AC5 off by default: full size at once, no ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_barChart(_bars)));
      expect(tester.binding.transientCallbackCount, 0);
      final full = _paintNow(tester, McBarChart).fillRects();
      expect(full, hasLength(3));
      expect(full[1].height, greaterThan(full[0].height));
    });

    testWidgets('T-0059-AC5 bars grow over the animation and settle', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_barChart(_bars)));
      final full = _paintNow(tester, McBarChart).fillRects();
      await tester.pumpWidget(_app(_barChart(_bars, animate: true)));
      expect(_paintNow(tester, McBarChart).fillRects(), isEmpty);
      await tester.pump(const Duration(milliseconds: 175));
      final mid = _paintNow(tester, McBarChart).fillRects();
      expect(mid, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(mid[i].height, greaterThan(0));
        expect(mid[i].height, lessThan(full[i].height));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(_paintNow(tester, McBarChart).fillRects(), full);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('T-0059-AC5 the donut sweeps in', (tester) async {
      await tester.pumpWidget(_app(_donutChart(_segments, animate: true)));
      final p = McPalette.light;
      final start = _paintNow(tester, McDonutChart).arcs();
      expect(start, hasLength(1), reason: 'only the empty track');
      expect(start.single.$4.color.toARGB32(), p.surfaceVariant.toARGB32());
      await tester.pump(const Duration(milliseconds: 175));
      final mid = _paintNow(tester, McDonutChart).arcs().where(
        (a) => a.$4.color.toARGB32() != p.surfaceVariant.toARGB32(),
      );
      final midTotal = mid.fold<double>(
        0,
        (a, x) => a + x.$3 + McDonutPainter.gap,
      );
      expect(midTotal, greaterThan(0.5));
      expect(midTotal, lessThan(6));
      await tester.pump(const Duration(milliseconds: 400));
      final end = _paintNow(tester, McDonutChart).arcs();
      expect(end, hasLength(3), reason: 'no track once drawn in');
      expect(
        end.fold<double>(0, (a, x) => a + x.$3 + McDonutPainter.gap),
        closeTo(2 * 3.141592653589793, 1e-9),
      );
    });

    testWidgets('T-0059-AC5 the line and the radar draw in', (tester) async {
      await tester.pumpWidget(_app(_lineChart(_lines, animate: true)));
      final p = _painterOf(tester, McLineChart) as McLinePainter;
      final size = tester.getSize(find.byType(CustomPaint).first);
      final bottom = p.layout(size).plot.bottom;
      expect(p.pointsOf(0, size).every((o) => o!.dy == bottom), isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.pointsOf(0, size).every((o) => o!.dy < bottom), isTrue);

      await tester.pumpWidget(_app(_radarChart(_radar, animate: true)));
      final r = _painterOf(tester, McRadarChart) as McRadarPainter;
      final rs = tester.getSize(find.byType(CustomPaint).first);
      final center = r.frame(rs).center;
      expect(
        r.polygonOf(0, rs).every((o) => (o - center).distance < 1e-9),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(r.polygonOf(0, rs).any((o) => (o - center).distance > 5), isTrue);
    });

    testWidgets('T-0059-AC5 reduced motion skips the animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_barChart(_bars, animate: true), disableAnimations: true),
      );
      expect(tester.binding.transientCallbackCount, 0);
      expect(_paintNow(tester, McBarChart).fillRects(), hasLength(3));
    });

    testWidgets('T-0059-AC5 changed data restarts it, equal data does not', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_barChart(_bars, animate: true)));
      await tester.pump(const Duration(milliseconds: 500));
      final full = _paintNow(tester, McBarChart).fillRects();
      await tester.pumpWidget(_app(_barChart([..._bars], animate: true)));
      expect(_paintNow(tester, McBarChart).fillRects(), full);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(
        _app(
          _barChart(const [
            McBarDatum(label: 'a', value: 1),
            McBarDatum(label: 'b', value: 2),
          ], animate: true),
        ),
      );
      expect(_paintNow(tester, McBarChart).fillRects(), isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_paintNow(tester, McBarChart).fillRects(), hasLength(2));
    });

    testWidgets('T-0059-AC5 switching animate off stops the ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_barChart(_bars, animate: true)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(_app(_barChart(_bars)));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_paintNow(tester, McBarChart).fillRects(), hasLength(3));
    });

    testWidgets('T-0059-AC5 switching animate on later starts it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_barChart(_bars)));
      await tester.pumpWidget(_app(_barChart(_bars, animate: true)));
      expect(_paintNow(tester, McBarChart).fillRects(), isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_paintNow(tester, McBarChart).fillRects(), hasLength(3));
    });

    testWidgets('T-0059-AC5 leaving mid-animation disposes the controller', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_donutChart(_segments, animate: true)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('T-0059-AC5 the empty state does not animate', (tester) async {
      await tester.pumpWidget(_app(_barChart(const [], animate: true)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(McEmptyView), findsOneWidget);
    });
  });
}

const _event1 = McTimelineEvent(date: '1962', title: 'First issue');
