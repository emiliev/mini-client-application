import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_testing/mc_ds_testing.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

void main() {
  test('T-0019-AC1 fonts: harness registers the name the app resolves', () {
    expect(mcRegisteredFontFamily, mcResolvedFontFamily);
    expect(McTypeScale.body.fontFamily, mcRegisteredFontFamily);
    expect(
      McTheme.light.textTheme.bodyMedium!.fontFamily,
      mcRegisteredFontFamily,
    );
  });

  testWidgets('T-0019-AC1 fonts: McTypeScale renders Inter, not Ahem', (
    tester,
  ) async {
    await mcLoadFonts();
    Future<Size> measure(TextStyle style) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text('Wiiiimmm', style: style),
          ),
        ),
      );
      return tester.getSize(find.byType(Text));
    }

    final inter = await measure(McTypeScale.body);
    final ahem = await measure(
      McTypeScale.body.copyWith(fontFamily: 'NoSuchFamily'),
    );
    // Ahem is monospaced (every glyph 1em); Inter is proportional.
    expect(inter.width, isNot(ahem.width));
  });
}
