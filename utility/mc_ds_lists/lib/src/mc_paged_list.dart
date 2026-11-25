import 'package:flutter/widgets.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_lists/src/paged_body.dart';
import 'package:mc_paging/mc_paging.dart';

/// A vertical list bound to a [PagedState].
///
/// - Asks for the next page once when scrolled past 80 %, never at the end,
///   after a failure (the footer then offers Retry) or while a request is in
///   flight. The owner turns `onLoadMore` into `PagingController.loadMore`.
/// - The first load shows [skeletonBuilder] rows (a spinner by default); an
///   empty settled state shows an empty view; a first-load failure shows a
///   full error view.
/// - Pull to refresh in the iOS style calls [onRefresh].
class McPagedList<T> extends StatelessWidget {
  const McPagedList({
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    required this.onRefresh,
    this.skeletonBuilder,
    this.skeletonCount = 6,
    this.separator = const McGap.sm(),
    this.padding = McInsets.horizontal,
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

  /// A placeholder row for the first load.
  final WidgetBuilder? skeletonBuilder;
  final int skeletonCount;
  final Widget separator;
  final EdgeInsets padding;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String footerErrorMessage;
  final String retryLabel;
  final String loadingLabel;
  final ScrollController? controller;

  Widget _rows(
    BuildContext context,
    int count,
    Widget Function(BuildContext, int) build,
  ) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList.separated(
        itemCount: count,
        itemBuilder: build,
        separatorBuilder: (_, _) => separator,
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
                _rows(context, skeletonCount, (ctx, _) => skeleton(ctx)),
      itemsSliver: (context, items) => _rows(
        context,
        items.length,
        (ctx, i) => itemBuilder(ctx, items[i], i),
      ),
    );
  }
}
