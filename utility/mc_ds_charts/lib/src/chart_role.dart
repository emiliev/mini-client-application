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

  /// The role for position [index] of a chart without explicit roles. Only
  /// meaningful up to [cycle].length positions; use [resolveAll] for a ring of
  /// segments.
  static McChartRole forIndex(int index) => cycle[index % cycle.length];

  /// Every role a default may fall back to when the cycle is used up. The first
  /// four are [cycle]; `positive` and `negative` come last because they carry
  /// meaning.
  static const List<McChartRole> _fallbackOrder = [
    McChartRole.series1,
    McChartRole.series2,
    McChartRole.series3,
    McChartRole.neutral,
    McChartRole.positive,
    McChartRole.negative,
  ];

  /// Resolves [given] (null = "pick a default") to one role per position so
  /// that neighbours never share a role, **including the last and the first**
  /// (a ring). A given role is kept as is. A default is the least-used role
  /// that differs from its neighbours, in [_fallbackOrder]; with up to four
  /// defaults and no explicit roles this is exactly [cycle].
  ///
  /// Charts that need more than four default colours should name their roles:
  /// the chart throws an [ArgumentError] in debug, and degrades with this in
  /// release.
  static List<McChartRole> resolveAll(List<McChartRole?> given) {
    final n = given.length;
    final out = <McChartRole?>[...given];
    final use = {for (final r in _fallbackOrder) r: 0};
    for (final r in given) {
      if (r != null) {
        use[r] = use[r]! + 1;
      }
    }
    for (var i = 0; i < n; i++) {
      if (out[i] != null) {
        continue;
      }
      final avoid = <McChartRole?>{
        if (i > 0) out[i - 1],
        if (i + 1 < n) out[i + 1],
        if (i == n - 1 && n > 1) out[0],
      };
      var best = _fallbackOrder.first;
      var bestUse = 1 << 30;
      for (final r in _fallbackOrder) {
        if (!avoid.contains(r) && use[r]! < bestUse) {
          best = r;
          bestUse = use[r]!;
        }
      }
      out[i] = best;
      use[best] = use[best]! + 1;
    }
    return [for (final r in out) r!];
  }
}
