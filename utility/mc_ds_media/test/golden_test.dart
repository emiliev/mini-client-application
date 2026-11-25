import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _art = 'packages/mc_fixtures_media/assets/characters/003.png';

Widget _scoped(ApiImage image) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 160,
      child: McImage(image: image, semanticLabel: 'Character art'),
    ),
  ),
);

void main() {
  // Placeholder: the load never completes, so the golden shows the wait state.
  final never = Completer<void>();
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'image_placeholder',
    height: 280,
    heightAtScale2: 280,
    assetBundle: McFixtureAssetBundle(gate: never.future),
    builder: (_) => _scoped(const ApiImage(path: 'mock-asset://characters/3')),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'image_loaded',
    height: 280,
    heightAtScale2: 280,
    assetBundle: McFixtureAssetBundle(),
    precache: const [_art],
    builder: (_) => _scoped(const ApiImage(path: 'mock-asset://characters/3')),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'image_fallback',
    height: 280,
    heightAtScale2: 280,
    assetBundle: McFixtureAssetBundle(),
    builder: (_) =>
        _scoped(const ApiImage(path: 'mock-asset://characters/999')),
  );
}
