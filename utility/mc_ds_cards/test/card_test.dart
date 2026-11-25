import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _image = ApiImage(path: 'mock-asset://characters/2');

Widget _app(Widget child, {double textScale = 1}) => mcGoldenApp(
  textScale: textScale,
  bundle: McFixtureAssetBundle(),
  child: McMediaScope(resolver: const BundledImageResolver(), child: child),
);

void main() {
  testWidgets('T-0031-AC5: the card is a button labelled with its title', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          height: McMediaCard.heightFor(
            width: 160,
            textScaler: TextScaler.noScaling,
          ),
          child: McMediaCard(
            image: _image,
            title: 'Wiimm the Wanderer',
            subtitle: 'Hero',
            onTap: () {},
          ),
        ),
      ),
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel('Wiimm the Wanderer'),
    );
    expect(
      node,
      isSemantics(isButton: true, isEnabled: true, label: 'Wiimm the Wanderer'),
    );
    expect(node.value, 'Hero');
    handle.dispose();
  });

  testWidgets('T-0031-AC5: the image adds no semantics node of its own', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          height: McMediaCard.heightFor(
            width: 160,
            textScaler: TextScaler.noScaling,
          ),
          child: McMediaCard(image: _image, title: 'Wiimm', onTap: () {}),
        ),
      ),
    );
    // One labelled node: the card. No second node for the picture.
    expect(find.bySemanticsLabel(RegExp('.+')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('T-0031-AC5: the tap target is at least 44 x 44', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 100,
            height: McMediaCard.heightFor(
              width: 100,
              textScaler: TextScaler.linear(scale),
            ),
            child: McMediaCard(image: _image, title: 'Wiimm', onTap: () {}),
          ),
          textScale: scale,
        ),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('T-0031-AC5: tapping the card calls onTap once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          height: McMediaCard.heightFor(
            width: 160,
            textScaler: TextScaler.noScaling,
          ),
          child: McMediaCard(
            image: _image,
            title: 'Wiimm',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(McMediaCard));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets(
    'T-0031-AC2: the skeleton card has no content, tap or semantics',
    (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 160,
            height: 300,
            child: McMediaCard.skeleton(),
          ),
        ),
      );
      expect(find.byType(McImage), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('T-0031-AC5: without onTap the card is not a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          height: McMediaCard.heightFor(
            width: 160,
            textScaler: TextScaler.noScaling,
          ),
          child: const McMediaCard(image: _image, title: 'Wiimm'),
        ),
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('Wiimm'));
    expect(node, isSemantics(isButton: false, label: 'Wiimm'));
    handle.dispose();
  });

  testWidgets('T-0031-AC4: a long title does not overflow at the large scale', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0, 3.0]) {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 160,
            height: McMediaCard.heightFor(
              width: 160,
              textScaler: TextScaler.linear(scale),
            ),
            child: McMediaCard(
              image: _image,
              title: 'Wiimm the Wanderer of the Nine Realms and Keeper of the Long Name',
              subtitle:
                  'A subtitle that is also much too long to fit on a line',
              onTap: () {},
            ),
          ),
          textScale: scale,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });

  test('T-0031-AC4: heightFor grows with the text scale and the width', () {
    final small = McMediaCard.heightFor(
      width: 160,
      textScaler: TextScaler.noScaling,
    );
    final large = McMediaCard.heightFor(
      width: 160,
      textScaler: const TextScaler.linear(2),
    );
    final wide = McMediaCard.heightFor(
      width: 320,
      textScaler: TextScaler.noScaling,
    );
    expect(large, greaterThan(small));
    expect(wide, greaterThan(small));
  });

  test('T-0034-AC5 heightFor without a subtitle is shorter by the subtitle '
      'line, and fewer title lines are shorter again', () {
    double h({bool sub = true, int lines = 2}) => McMediaCard.heightFor(
      width: 160,
      textScaler: TextScaler.noScaling,
      hasSubtitle: sub,
      titleLines: lines,
    );
    expect(h(sub: false), lessThan(h()));
    expect(h(lines: 1), lessThan(h()));
    // The defaults keep the old two-line title plus subtitle.
    expect(
      McMediaCard.heightFor(width: 160, textScaler: TextScaler.noScaling),
      h(),
    );
  });

  testWidgets('T-0034-AC5 a card without a subtitle fits the shorter height, '
      'at every text scale', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        _app(
          textScale: scale,
          SizedBox(
            width: 160,
            height: McMediaCard.heightFor(
              width: 160,
              textScaler: TextScaler.linear(scale),
              hasSubtitle: false,
            ),
            child: const McMediaCard(
              image: _image,
              title: 'A very long character name that wraps over two lines',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });
}
