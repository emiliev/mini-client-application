import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_paging/mc_paging.dart';

/// The share of the scrollable extent after which the next page is requested.
const double mcPagedLoadMoreThreshold = 0.8;

/// Everything `McPagedList` and `McPagedGrid` share: the state to view
/// mapping, the load-more trigger, the footer and the refresh control. The two
/// widgets differ only in the sliver that holds the items.
class PagedBody<T> extends StatefulWidget {
  const PagedBody({
    required this.state,
    required this.itemsSliver,
    required this.skeletonSliver,
    required this.onLoadMore,
    required this.onRetry,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.errorTitle,
    required this.footerErrorMessage,
    required this.retryLabel,
    this.controller,
    super.key,
  });

  final PagedState<T> state;

  /// The sliver that shows [PagedState.items].
  final Widget Function(BuildContext context, List<T> items) itemsSliver;

  /// The sliver shown while the first page loads. Null: a centred spinner.
  final Widget Function(BuildContext context)? skeletonSliver;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String footerErrorMessage;
  final String retryLabel;
  final ScrollController? controller;

  @override
  State<PagedBody<T>> createState() => _PagedBodyState<T>();
}

class _PagedBodyState<T> extends State<PagedBody<T>> {
  /// Set when `onLoadMore` was called for the current state; cleared when the
  /// state changes. A scroll burst before the owner reacts asks only once.
  bool _requested = false;

  @override
  void didUpdateWidget(PagedBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _requested = false;
    }
  }

  bool get _canLoadMore {
    final s = widget.state;
    return !_requested &&
        s.items.isNotEmpty &&
        !s.hasReachedEnd &&
        !s.isLoadingMore &&
        s.failure == null;
  }

  bool _pastThreshold(ScrollMetrics m) =>
      m.axis == Axis.vertical &&
      m.pixels >= m.maxScrollExtent * mcPagedLoadMoreThreshold;

  void _request() {
    _requested = true;
    widget.onLoadMore();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && _canLoadMore && _pastThreshold(n.metrics)) {
      if (n is ScrollMetricsNotification) {
        // Sent during layout: ask once the frame is done. This is the case of
        // a list that does not fill the viewport yet.
        _requested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onLoadMore();
          }
        });
      } else {
        _request();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final firstLoad = s.items.isEmpty;
    final Widget content;
    if (firstLoad && s.failure != null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: McErrorView(
          title: widget.errorTitle,
          message: s.failure!.message,
          retryLabel: widget.retryLabel,
          onRetry: widget.onRetry,
        ),
      );
    } else if (firstLoad && s.hasReachedEnd && !s.isLoadingMore) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: McEmptyView(
          title: widget.emptyTitle,
          message: widget.emptyMessage,
        ),
      );
    } else if (firstLoad) {
      content =
          widget.skeletonSliver?.call(context) ??
          const SliverFillRemaining(
            hasScrollBody: false,
            child: McLoading(),
          );
    } else {
      content = widget.itemsSliver(context, s.items);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        controller: widget.controller,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
          content,
          if (!firstLoad)
            SliverToBoxAdapter(
              child: _Footer(
                state: s,
                message: widget.footerErrorMessage,
                retryLabel: widget.retryLabel,
                onRetry: widget.onRetry,
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final PagedState<Object?> state;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.failure != null) {
      final p = context.mcPalette;
      return Padding(
        padding: McInsets.screen,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.error),
                ),
              ),
            ),
            const McGap.md(),
            McButton(
              label: retryLabel,
              variant: McButtonVariant.tertiary,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    if (state.isLoadingMore) {
      return const SizedBox(
        height: 72,
        child: McLoading(semanticLabel: 'Loading more'),
      );
    }
    return const McGap.lg();
  }
}
