import 'package:flutter/material.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _art = 'packages/mc_fixtures_media/assets/characters/005.png';
const _image = ApiImage(path: 'mock-asset://characters/5');

/// One card in a cell sized as the grid would size it.
Widget _cell(Widget card) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 165,
        height: McMediaCard.heightFor(
          width: 165,
          textScaler: MediaQuery.textScalerOf(context),
        ),
        child: card,
      ),
    ),
  ),
);

void main() {
  final bundle = McFixtureAssetBundle();
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'card_normal',
    height: 320,
    heightAtScale2: 400,
    assetBundle: bundle,
    precache: const [_art],
    builder: (_) => _cell(
      McMediaCard(
        image: _image,
        title: 'Wiimm the Wanderer',
        subtitle: 'Hero',
        onTap: () {},
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'card_long_title',
    height: 320,
    heightAtScale2: 400,
    assetBundle: bundle,
    precache: const [_art],
    builder: (_) => _cell(
      McMediaCard(
        image: _image,
        title: 'Wiimm the Wanderer of the Nine Realms and Keeper of the Long Name',
        subtitle: 'A subtitle that is also much too long to fit on a line',
        onTap: () {},
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'card_skeleton',
    height: 320,
    heightAtScale2: 400,
    builder: (_) => _cell(const McMediaCard.skeleton()),
  );
}
