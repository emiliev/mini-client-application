// Verifier probe (T-0031), kept as evidence. To re-run, copy into the package test/ dir with a flutter_test target (deps = _TEST_DEPS).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _art = 'packages/mc_fixtures_media/assets/characters/002.png';

void main() {
  final bundle = McFixtureAssetBundle();
  for (final variant in McThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('A11Y card ${variant.name} x$scale', (t) async {
        await mcLoadFonts();
        final h = t.ensureSemantics();
        mcSetSurface(t, 375, 700);
        await mcPrecacheFixtureImages(t, bundle, [_art]);
        await t.pumpWidget(
          mcGoldenApp(
            variant: variant,
            textScale: scale,
            bundle: bundle,
            child: McMediaScope(
              resolver: const BundledImageResolver(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final title in ['Wiimm the Wanderer', 'Nova'])
                      SizedBox(
                        width: 160,
                        height: McMediaCard.heightFor(
                          width: 160,
                          textScaler: TextScaler.linear(scale),
                        ),
                        child: McMediaCard(
                          image: const ApiImage(
                            path: 'mock-asset://characters/2',
                          ),
                          title: title,
                          subtitle: 'Hero',
                          onTap: () {},
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pump();
        final node = t.getSemantics(find.bySemanticsLabel('Nova'));
        print(
          'A11Y ${variant.name} x$scale node: ${node.getSemanticsData()} '
          'rect=${node.rect}',
        );
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }
  }
}
