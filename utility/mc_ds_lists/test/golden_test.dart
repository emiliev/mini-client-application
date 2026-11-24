import 'package:flutter/material.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'support.dart';

const _titles = [
  'Wiimm the Wanderer',
  'Captain Pell of the Long Name and Many Titles',
  'Nova',
  'Brisk Harlow',
  'Orrin',
  'Sable',
];

final _art = [
  for (var i = 0; i < _titles.length; i++)
    'packages/mc_fixtures_media/assets/characters/${i.toString().padLeft(3, '0')}.png',
];

Widget _grid(PagedState<int> state) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: SizedBox(
    width: 375,
    height: 640,
    child: McPagedGrid<int>(
      state: state,
      onLoadMore: () {},
      onRetry: () {},
      onRefresh: () async {},
      emptyMessage: 'No characters match your search.',
      cellHeight: (width, scaler) =>
          McMediaCard.heightFor(width: width, textScaler: scaler),
      skeletonBuilder: (_) => const McMediaCard.skeleton(),
      itemBuilder: (context, item, index) => McMediaCard(
        image: ApiImage(path: 'mock-asset://characters/$item'),
        title: _titles[item],
        subtitle: 'Hero',
        onTap: () {},
      ),
    ),
  ),
);

void main() {
  final bundle = McFixtureAssetBundle();

  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'grid_loading',
    height: 640,
    heightAtScale2: 640,
    assetBundle: bundle,
    builder: (_) => _grid(const PagedState<int>(isLoadingMore: true)),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'grid_loaded',
    height: 640,
    heightAtScale2: 640,
    assetBundle: bundle,
    precache: _art,
    builder: (_) => _grid(pagedState(6, hasReachedEnd: true)),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'grid_error_footer',
    height: 640,
    heightAtScale2: 640,
    assetBundle: bundle,
    precache: _art,
    builder: (_) =>
        _grid(pagedState(2, failure: const ApiFailure.offline('Offline'))),
  );
  mcGoldenMatrix(
    acId: 'T-0031-AC4',
    component: 'grid_empty',
    height: 640,
    heightAtScale2: 640,
    assetBundle: bundle,
    builder: (_) => _grid(const PagedState<int>(hasReachedEnd: true)),
  );
}
