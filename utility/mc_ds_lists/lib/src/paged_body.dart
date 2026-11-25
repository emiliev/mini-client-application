import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
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
    this.loadingLabel = 'Loading',
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

  /// The one announcement for the whole skeleton while the first page loads.
  final String loadingLabel;
  final ScrollController? controller;

  @override
  State<PagedBody<T>> createState() => _PagedBodyState<T>();
}

class _PagedBodyState<T> extends State<PagedBody<T>> {
  /// Set when `onLoadMore` was called for the current state; cleared when the
  /// state changes or the scroll position goes back below the threshold. A
  /// scroll burst before the owner reacts asks only once.
  bool _requested = false;

  final ScrollController _own = ScrollController();

  ScrollController get _controller => widget.controller ?? _own;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(PagedBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _requested = false;
      // A page that does not fill the viewport never scrolls, and the metrics
      // do not change when the extent stays 0: look at the position once the
      // frame is laid out, so a short page still asks for the next one.
      _scheduleCheck();
    }
  }

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _scheduleCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        final position = _controller.position;
        if (position.hasContentDimensions) {
          _maybeRequest(position, 0);
        }
      }
    });
  }

  bool get _canLoadMore {
    final s = widget.state;
    return s.items.isNotEmpty &&
        !s.hasReachedEnd &&
        !s.isLoadingMore &&
        s.failure == null;
  }

  bool _pastThreshold(ScrollMetrics m) =>
      m.axis == Axis.vertical &&
      m.pixels >= m.maxScrollExtent * mcPagedLoadMoreThreshold;

  /// Asks the owner for the next page when [m] is past the threshold and no
  /// request is outstanding for the current state. Going back below the
  /// threshold clears the latch, so a dropped request is retried by scrolling.
  void _maybeRequest(ScrollMetrics m, int depth) {
    if (depth != 0 || !_canLoadMore) {
      return;
    }
    if (!_pastThreshold(m)) {
      _requested = false;
    } else if (!_requested) {
      _requested = true;
      widget.onLoadMore();
    }
  }

  bool _onScroll(ScrollNotification n) {
    _maybeRequest(n.metrics, n.depth);
    return false;
  }

  /// Sent after layout when the extents change.
  bool _onMetrics(ScrollMetricsNotification n) {
    _maybeRequest(n.metrics, n.depth);
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
      final skeleton = widget.skeletonSliver?.call(context);
      content = skeleton == null
          ? const SliverFillRemaining(hasScrollBody: false, child: McLoading())
          : SliverSemantics(
              label: widget.loadingLabel,
              liveRegion: true,
              container: true,
              excludeSemantics: true,
              sliver: skeleton,
            );
    } else {
      content = widget.itemsSliver(context, s.items);
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          controller: _controller,
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
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(color: p.error),
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
