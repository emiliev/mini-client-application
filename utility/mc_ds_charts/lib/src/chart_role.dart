import 'package:flutter/painting.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A colour role of a chart. Charts take roles, never colours, so every theme
/// (light, dark and both high-contrast ones) draws its own accessible shade.
enum McChartRole {
  series1,
  series2,
  series3,
  positive,
  negative,
  neutral;

  /// The role's colour in [palette].
  Color resolve(McPalette palette) => switch (this) {
    McChartRole.series1 => palette.series1,
    McChartRole.series2 => palette.series2,
    McChartRole.series3 => palette.series3,
    McChartRole.positive => palette.positive,
    McChartRole.negative => palette.negative,
    McChartRole.neutral => palette.neutral,
  };

  /// The roles a chart cycles through when its data names none.
  static const List<McChartRole> cycle = [
    McChartRole.series1,
    McChartRole.series2,
    McChartRole.series3,
    McChartRole.neutral,
  ];

  /// The role for position [index] of a chart without explicit roles.
  static McChartRole forIndex(int index) => cycle[index % cycle.length];
}
