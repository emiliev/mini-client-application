import 'package:flutter/widgets.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_lists/src/paged_body.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_paging/mc_paging.dart';

/// The height of one grid cell [cellWidth] wide at [textScaler].
typedef McCellHeight = double Function(double cellWidth, TextScaler textScaler);

/// A grid bound to a [PagedState]. Behaves like `McPagedList` (80 % load-more
/// trigger, footer, empty and error views, pull to refresh) and chooses its
/// column count from the width: 2, 3 or 4 (`McWidthClass`).
///
/// Cells are [cellHeight] tall. It is required: a cell with text must grow
/// with the text scale, and a wrong default would silently clip the text. A
/// card supplies the matching function (`McMediaCard.heightFor`).
class McPagedGrid<T> extends StatelessWidget {
  const McPagedGrid({
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    required this.onRefresh,
    required this.cellHeight,
    this.skeletonBuilder,
    this.skeletonCount = 6,
    this.spacing = McSpacing.md,
    this.padding = McInsets.screen,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'There is nothing to show.',
    this.errorTitle = 'Something went wrong',
    this.footerErrorMessage = 'Could not load.',
    this.loadingLabel = 'Loading',
    this.retryLabel = 'Retry',
    this.controller,
    super.key,
  });

  final PagedState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  /// A placeholder cell for the first load.
  final WidgetBuilder? skeletonBuilder;
  final int skeletonCount;
  final McCellHeight cellHeight;
  final double spacing;
  final EdgeInsets padding;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String footerErrorMessage;
  final String retryLabel;
  final String loadingLabel;
  final ScrollController? controller;

  Widget _grid(
    BuildContext context,
    int count,
    Widget Function(BuildContext, int) build,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final extent = constraints.crossAxisExtent;
          final columns = McWidthClass.of(extent + padding.horizontal).columns;
          final cellWidth = (extent - spacing * (columns - 1)) / columns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: cellHeight(cellWidth, textScaler),
            ),
            delegate: SliverChildBuilderDelegate(
              build,
              childCount: count,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skeleton = skeletonBuilder;
    return PagedBody<T>(
      state: state,
      controller: controller,
      onLoadMore: onLoadMore,
      onRetry: onRetry,
      onRefresh: onRefresh,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      errorTitle: errorTitle,
      footerErrorMessage: footerErrorMessage,
      retryLabel: retryLabel,
      loadingLabel: loadingLabel,
      skeletonSliver: skeleton == null
          ? null
          : (context) =>
                _grid(context, skeletonCount, (ctx, _) => skeleton(ctx)),
      itemsSliver: (context, items) => _grid(
        context,
        items.length,
        (ctx, i) => itemBuilder(ctx, items[i], i),
      ),
    );
  }
}
