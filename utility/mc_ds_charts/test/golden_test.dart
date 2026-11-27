// T-0059-AC1: every chart in every state, in 4 themes x 2 text scales.
import 'package:flutter/material.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _msg = 'No data yet.';
const _msgDe = 'Noch keine Daten für diesen Zeitraum vorhanden.';

void _golden(
  String component,
  Widget Function() chart, {
  double height = 300,
  double heightAtScale2 = 420,
}) {
  mcGoldenMatrix(
    acId: 'T-0059-AC1',
    component: component,
    builder: (context) => SizedBox.expand(
      child: ColoredBox(
        color: context.mcPalette.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: Alignment.topCenter, child: chart()),
        ),
      ),
    ),
    height: height,
    heightAtScale2: heightAtScale2,
  );
}

McBarChart _bar(
  List<McBarDatum> data, {
  Axis orientation = Axis.vertical,
  int? highlight,
  String empty = _msg,
}) => McBarChart(
  data: data,
  semanticLabel: 'Bar chart',
  emptyMessage: empty,
  orientation: orientation,
  highlightIndex: highlight,
);

const _week = [
  McBarDatum(label: 'Mon', value: 4),
  McBarDatum(label: 'Tue', value: 7),
  McBarDatum(label: 'Wed', value: 2),
  McBarDatum(label: 'Thu', value: 9),
  McBarDatum(label: 'Fri', value: 5),
];

const _german = [
  McBarDatum(label: 'Durchschnittsgeschwindigkeit', value: 42),
  McBarDatum(label: 'Höchstgeschwindigkeit', value: 77),
  McBarDatum(label: 'Donaudampfschifffahrt', value: 15),
  McBarDatum(label: 'Zeit', value: 60),
];

void main() {
  // --- bars -----------------------------------------------------------------
  _golden('bar_vertical', () => _bar(_week), heightAtScale2: 320);
  _golden(
    'bar_roles_highlight',
    () => _bar(const [
      McBarDatum(label: 'Mon', value: 4, role: McChartRole.negative),
      McBarDatum(label: 'Tue', value: 7, role: McChartRole.positive),
      McBarDatum(label: 'Wed', value: 2, role: McChartRole.series2),
      McBarDatum(label: 'Thu', value: 9, role: McChartRole.series3),
      McBarDatum(label: 'Fri', value: 5, role: McChartRole.neutral),
    ], highlight: 3),
    heightAtScale2: 320,
  );
  _golden(
    'bar_negative',
    () => _bar(const [
      McBarDatum(label: 'Q1', value: 12, role: McChartRole.positive),
      McBarDatum(label: 'Q2', value: -8, role: McChartRole.negative),
      McBarDatum(label: 'Q3', value: 5, role: McChartRole.positive),
      McBarDatum(label: 'Q4', value: -15, role: McChartRole.negative),
    ]),
    heightAtScale2: 320,
  );
  _golden('bar_german_labels', () => _bar(_german), heightAtScale2: 320);
  _golden(
    'bar_thirty',
    () => _bar([
      for (var i = 0; i < 30; i++)
        McBarDatum(label: 'Tag ${i + 1}', value: ((i * 7) % 11) + 1.0),
    ]),
    heightAtScale2: 320,
  );
  _golden(
    'bar_horizontal',
    () => _bar(_week, orientation: Axis.horizontal),
    height: 340,
    heightAtScale2: 520,
  );
  _golden(
    'bar_horizontal_german_negative',
    () => _bar(const [
      McBarDatum(label: 'Durchschnittsgeschwindigkeit', value: 42),
      McBarDatum(label: 'Höchstgeschwindigkeit', value: -30),
      McBarDatum(label: 'Zeit', value: 60),
    ], orientation: Axis.horizontal),
    height: 300,
    heightAtScale2: 480,
  );
  _golden(
    'bar_single',
    () => _bar(const [McBarDatum(label: 'Only', value: 6)]),
    heightAtScale2: 320,
  );
  _golden(
    'bar_all_zero',
    () => _bar(const [
      McBarDatum(label: 'A', value: 0),
      McBarDatum(label: 'B', value: 0),
      McBarDatum(label: 'C', value: 0),
    ]),
    heightAtScale2: 320,
  );
  _golden('bar_empty', () => _bar(const []), height: 360, heightAtScale2: 640);
  _golden(
    'bar_empty_german',
    () => _bar(const [], empty: _msgDe),
    height: 360,
    heightAtScale2: 720,
  );

  // --- donut ----------------------------------------------------------------
  McDonutChart donut(
    List<McDonutSegment> data, {
    String? centre,
    String caption = 'answers',
    String empty = _msg,
  }) => McDonutChart(
    data: data,
    semanticLabel: 'Donut chart',
    emptyMessage: empty,
    centerLabel: centre,
    centerCaption: centre == null ? null : caption,
  );
  _golden(
    'donut_basic',
    () => donut(const [
      McDonutSegment(label: 'Right', value: 8),
      McDonutSegment(label: 'Wrong', value: 3),
      McDonutSegment(label: 'Skipped', value: 1),
    ], centre: '12'),
    height: 320,
    heightAtScale2: 460,
  );
  _golden(
    'donut_tiny_segments',
    () => donut(const [
      McDonutSegment(label: 'Right', value: 1000),
      McDonutSegment(label: 'Wrong', value: 2),
      McDonutSegment(label: 'Skipped', value: 1),
      McDonutSegment(label: 'Timed out', value: 0.5),
    ], centre: '1003'),
    height: 340,
    heightAtScale2: 520,
  );
  _golden(
    'donut_german',
    () => donut(
      const [
        McDonutSegment(label: 'Richtige Antworten insgesamt', value: 80),
        McDonutSegment(label: 'Falsche Antworten insgesamt', value: 30),
        McDonutSegment(label: 'Übersprungene Fragen', value: 10),
      ],
      centre: '120',
      caption: 'Antworten',
    ),
    height: 360,
    heightAtScale2: 560,
  );
  _golden(
    'donut_single',
    () => donut(const [McDonutSegment(label: 'All', value: 5)], centre: '5'),
    height: 320,
    heightAtScale2: 440,
  );
  _golden(
    'donut_all_zero',
    () => donut(const [
      McDonutSegment(label: 'Right', value: 0),
      McDonutSegment(label: 'Wrong', value: 0),
    ], centre: '0'),
    height: 320,
    heightAtScale2: 440,
  );
  _golden(
    'donut_empty',
    () => donut(const []),
    height: 360,
    heightAtScale2: 640,
  );

  // --- line -----------------------------------------------------------------
  McLineChart line(
    List<McLineSeries> series, {
    List<String> x = const ['Q1', 'Q2', 'Q3', 'Q4'],
    String empty = _msg,
  }) => McLineChart(
    xLabels: x,
    series: series,
    semanticLabel: 'Line chart',
    emptyMessage: empty,
  );
  _golden(
    'line_one_series',
    () => line(const [
      McLineSeries(label: 'Readers', values: [3, 5, 4, 8]),
    ]),
    heightAtScale2: 340,
  );
  _golden(
    'line_three_series',
    () => line(const [
      McLineSeries(label: 'Print', values: [3, 5, 4, 8]),
      McLineSeries(label: 'Digital', values: [1, 2, 6, 7]),
      McLineSeries(label: 'Audio', values: [0, 1, 1, 3]),
    ]),
    height: 330,
    heightAtScale2: 440,
  );
  _golden(
    'line_negative_gap_german',
    () => line(
      const [
        McLineSeries(
          label: 'Gedruckte Ausgaben',
          values: [-3, 2, 3, 5],
        ),
        McLineSeries(label: 'Digitale Ausgaben', values: [1, -2, 4, -1]),
      ],
      x: const ['Erstes Quartal', 'Zweites Quartal', 'Drittes', 'Viertes'],
    ),
    height: 340,
    heightAtScale2: 460,
  );
  _golden(
    'line_single_point',
    () => line(
      const [
        McLineSeries(label: 'Only', values: [4]),
      ],
      x: const ['Now'],
    ),
    heightAtScale2: 340,
  );
  _golden('line_empty', () => line(const []), height: 360, heightAtScale2: 640);

  // --- radar ----------------------------------------------------------------
  McRadarChart radar(
    List<McRadarSeries> series,
    List<String> axes, {
    String empty = _msg,
  }) => McRadarChart(
    axes: axes,
    series: series,
    semanticLabel: 'Radar chart',
    emptyMessage: empty,
  );
  _golden(
    'radar_one_series',
    () => radar(
      const [
        McRadarSeries(label: 'Hulk', values: [0.4, 1, 0.3, 0.2, 0.7]),
      ],
      const ['Speed', 'Power', 'Brains', 'Luck', 'Heart'],
    ),
    height: 340,
    heightAtScale2: 400,
  );
  _golden(
    'radar_two_series_eight_axes',
    () => radar(
      const [
        McRadarSeries(
          label: 'Hulk',
          values: [0.4, 1, 0.3, 0.2, 0.7, 0.5, 0.9, 0.1],
        ),
        McRadarSeries(
          label: 'Stark',
          values: [0.5, 0.6, 1, 0.9, 0.3, 0.8, 0.2, 0.6],
        ),
      ],
      const [
        'Speed',
        'Power',
        'Brains',
        'Luck',
        'Heart',
        'Aim',
        'Armor',
        'Fun',
      ],
    ),
    height: 380,
    heightAtScale2: 480,
  );
  _golden(
    'radar_three_axes_german',
    () => radar(
      const [
        McRadarSeries(label: 'Held', values: [0.4, 1, 0.6]),
      ],
      const ['Geschwindigkeit', 'Durchhaltevermögen', 'Intelligenz'],
    ),
    height: 340,
    heightAtScale2: 400,
  );
  _golden(
    'radar_empty',
    () => radar(const [], const []),
    height: 360,
    heightAtScale2: 640,
  );

  // --- timeline -------------------------------------------------------------
  McTimeline timeline(List<McTimelineEvent> events) => McTimeline(
    events: events,
    semanticLabel: 'Timeline',
    emptyMessage: _msg,
  );
  _golden(
    'timeline_basic',
    () => timeline(const [
      McTimelineEvent(
        date: 'Aug 1962',
        title: 'First issue',
        description: 'The character debuts.',
      ),
      McTimelineEvent(
        date: 'May 1984',
        title: 'Secret Wars',
        role: McChartRole.negative,
      ),
      McTimelineEvent(
        date: 'May 2008',
        title: 'Iron Man',
        description: 'The first film of a new universe.',
        role: McChartRole.positive,
      ),
    ]),
    height: 380,
    heightAtScale2: 760,
  );
  _golden(
    'timeline_german_single',
    () => timeline(const [
      McTimelineEvent(
        date: 'Neunzehnhundertzweiundsechzig',
        title: 'Veröffentlichungsgeschichte der ersten Ausgabe',
        description: 'Donaudampfschifffahrtsgesellschaftskapitän',
      ),
    ]),
    height: 300,
    heightAtScale2: 700,
  );
  _golden(
    'timeline_empty',
    () => timeline(const []),
    height: 360,
    heightAtScale2: 640,
  );
}
