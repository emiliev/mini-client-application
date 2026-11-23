import 'dart:ui' show Brightness;
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test(
    'T-0019-AC1 tokens: text pairs meet WCAG AA, high contrast meets AAA',
    () {
      for (final v in McThemeVariant.values) {
        final p = McPalette.of(v);
        final min =
            (v == McThemeVariant.highContrast ||
                v == McThemeVariant.highContrastDark)
            ? 7.0
            : 4.5;
        expect(_contrast(p.onSurface, p.surface), greaterThanOrEqualTo(min));
        expect(_contrast(p.onSurface, p.background), greaterThanOrEqualTo(min));
        expect(_contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(min));
        expect(_contrast(p.onError, p.error), greaterThanOrEqualTo(min));
        expect(
          _contrast(p.onSurfaceMuted, p.surface),
          greaterThanOrEqualTo(min),
        );
      }
    },
  );

  test('T-0019-AC1 tokens: scales are ordered and use the bundled family', () {
    expect(McSpacing.xs, lessThan(McSpacing.sm));
    expect(McSpacing.sm, lessThan(McSpacing.lg));
    expect(
      McTypeScale.display.fontSize,
      greaterThan(McTypeScale.body.fontSize!),
    );
    for (final s in [
      McTypeScale.body,
      McTypeScale.title,
      McTypeScale.caption,
    ]) {
      expect(s.fontFamily, mcResolvedFontFamily);
    }
    expect(mcMinTapTarget, 44);
  });

  test('T-0019-AC1 tokens: every type style resolves to the package font', () {
    expect(mcResolvedFontFamily, 'packages/mc_ds_theme/Inter');
    for (final s in [
      McTypeScale.display,
      McTypeScale.title,
      McTypeScale.headline,
      McTypeScale.body,
      McTypeScale.label,
      McTypeScale.caption,
    ]) {
      expect(s.fontFamily, mcResolvedFontFamily);
    }
  });

  test('T-0019-AC1 tokens: palette lerp interpolates colours', () {
    final mid = McPalette.lerp(McPalette.light, McPalette.dark, 0.5);
    expect(mid.surface, isNot(McPalette.light.surface));
    expect(mid.surface, isNot(McPalette.dark.surface));
    expect(
      McPalette.lerp(McPalette.light, McPalette.dark, 0).surface,
      McPalette.light.surface,
    );
    expect(
      McPalette.lerp(McPalette.light, McPalette.dark, 1).brightness,
      Brightness.dark,
    );
  });

  test('T-0019-AC1 tokens: dark high contrast is dark and distinct', () {
    expect(McPalette.highContrastDark.brightness, Brightness.dark);
    expect(McPalette.highContrastDark, isNot(McPalette.highContrast));
  });

  test('T-0019-AC1 tokens: McPalette has value equality', () {
    expect(McPalette.of(McThemeVariant.light), McPalette.light);
    expect(McPalette.light.hashCode, McPalette.light.hashCode);
    expect(McPalette.light == McPalette.dark, isFalse);
    expect(McPalette.lerp(McPalette.light, McPalette.dark, 0), McPalette.light);
  });
}
