import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _long =
    'A very long page title that keeps going well past the width of any phone';

const _five = [
  McTab(label: 'Overview'),
  McTab(label: 'Comics'),
  McTab(label: 'Events'),
  McTab(label: 'Series'),
  McTab(label: 'Stories'),
];

Widget _bar(McAppBar bar) =>
    SizedBox(width: 375, height: bar.preferredSize.height, child: bar);

Widget _action(IconData icon, String label) => McIconButton(
  icon: icon,
  semanticLabel: label,
  onPressed: () {},
);

void main() {
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'app_bar_plain',
    height: 80,
    heightAtScale2: 80,
    builder: (_) => _bar(const McAppBar(title: 'Characters')),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'app_bar_actions',
    height: 80,
    heightAtScale2: 80,
    builder: (_) => _bar(
      McAppBar(
        title: 'Characters',
        leading: const BackButton(),
        actions: [
          _action(Icons.search, 'Search'),
          _action(Icons.favorite_border, 'Favourite'),
        ],
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'app_bar_large_title',
    height: 140,
    heightAtScale2: 140,
    builder: (_) => _bar(
      McAppBar(
        title: 'Characters',
        largeTitle: true,
        leading: const BackButton(),
        actions: [_action(Icons.search, 'Search')],
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'app_bar_long_title',
    height: 80,
    heightAtScale2: 80,
    builder: (_) => _bar(
      McAppBar(
        title: _long,
        leading: const BackButton(),
        actions: [_action(Icons.search, 'Search')],
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'app_bar_long_title_large',
    height: 140,
    heightAtScale2: 140,
    builder: (_) => _bar(const McAppBar(title: _long, largeTitle: true)),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'tab_bar_2',
    height: 80,
    heightAtScale2: 100,
    builder: (_) => McTabBar(
      tabs: const [
        McTab(label: 'Overview'),
        McTab(label: 'Comics'),
      ],
      currentIndex: 0,
      onChanged: (_) {},
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'tab_bar_5',
    height: 80,
    heightAtScale2: 100,
    settle: const Duration(milliseconds: 300),
    builder: (_) => McTabBar(tabs: _five, currentIndex: 2, onChanged: (_) {}),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'section_header',
    height: 100,
    heightAtScale2: 160,
    builder: (_) => const McSectionHeader(title: 'Featured characters'),
  );
  mcGoldenMatrix(
    acId: 'T-0040-AC1',
    component: 'section_header_action',
    height: 100,
    heightAtScale2: 280,
    builder: (_) => McSectionHeader(
      title: 'Featured characters in the long-running series',
      actionLabel: 'See all',
      onAction: () {},
    ),
  );
}
