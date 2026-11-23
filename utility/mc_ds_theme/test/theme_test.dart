import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

void main() {
  test('T-0019-AC1 theme: each variant carries its palette and font', () {
    for (final v in McThemeVariant.values) {
      final t = McTheme.of(v);
      expect(t.extension<McThemeExtension>()!.palette, McPalette.of(v));
      expect(t.colorScheme.primary, McPalette.of(v).primary);
      expect(t.textTheme.bodyMedium!.fontFamily, mcFontFamily);
    }
    expect(McTheme.dark.brightness, Brightness.dark);
    expect(McTheme.highContrast.brightness, Brightness.light);
  });

  test('T-0019-AC1 theme: variantFor honours high contrast first', () {
    expect(
      McTheme.variantFor(brightness: Brightness.dark, highContrast: true),
      McThemeVariant.highContrast,
    );
    expect(
      McTheme.variantFor(brightness: Brightness.dark),
      McThemeVariant.dark,
    );
    expect(
      McTheme.variantFor(brightness: Brightness.light),
      McThemeVariant.light,
    );
  });

  test('T-0019-AC1 theme: mode controller notifies on change only', () {
    final c = McThemeModeController();
    var calls = 0;
    c.addListener(() => calls++);
    expect(c.value, ThemeMode.system);
    c.setMode(ThemeMode.dark);
    c.setMode(ThemeMode.dark);
    expect(calls, 1);
    expect(c.value, ThemeMode.dark);
  });

  testWidgets('T-0019-AC1 theme: context.mcPalette resolves from the tree', (
    tester,
  ) async {
    late McPalette seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: McTheme.dark,
        home: Builder(
          builder: (c) {
            seen = c.mcPalette;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, McPalette.dark);
  });
}
