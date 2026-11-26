import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One tab of a [McTabBar].
@immutable
class McTab {
  const McTab({required this.label, this.key});

  final String label;

  /// Key of this tab, for tests.
  final Key? key;
}

/// A controlled tab bar: the owner holds [currentIndex] and reacts to
/// [onChanged]. It does not need a `TabController`.
///
/// **Size.** The bar is exactly [height] tall plus a [dividerHeight] divider,
/// whatever its parent's height, and it is a [PreferredSizeWidget], so it
/// works as `AppBar.bottom` (or `McAppBar.bottom`). Because the height is
/// fixed, the labels' text scale is capped at [labelMaxScale].
///
/// **Width.** When the tabs fit, each tab takes its share of the width (its
/// own width plus an equal part of the free space), so a tap anywhere on the
/// bar selects a tab. When they do not fit, the row scrolls horizontally on
/// its own controller, and the selected tab is revealed when the selection
/// changes (and on the first build); no ancestor scroll view moves. With an
/// unbounded width (a `Row` without `Expanded`) the bar is as wide as its
/// tabs and does not scroll.
///
/// Each tab is at least [mcMinTapTarget] wide and [height] tall, and is a
/// selectable tab for screen readers. Works without a `Scaffold`.
class McTabBar extends StatefulWidget implements PreferredSizeWidget {
  const McTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
    super.key,
  }) : assert(tabs.length >= 2, 'a tab bar has at least two tabs'),
       assert(
         currentIndex >= 0 && currentIndex < tabs.length,
         'currentIndex must be a valid tab index',
       );

  final List<McTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Height of the tabs.
  static const double height = 48;

  /// Height of the divider under the tabs.
  static const double dividerHeight = 1;

  /// Cap of the label text scale (the tabs have a fixed height).
  static const double labelMaxScale = 1.5;

  @override
  Size get preferredSize => const Size.fromHeight(height + dividerHeight);

  @override
  State<McTabBar> createState() => _McTabBarState();
}

class _McTabBarState extends State<McTabBar> {
  final ScrollController _controller = ScrollController();
  late List<GlobalKey> _keys = _newKeys();

  List<GlobalKey> _newKeys() => List.generate(
    widget.tabs.length,
    (i) => GlobalKey(debugLabel: 'McTabBar tab $i'),
  );

  @override
  void initState() {
    super.initState();
    _reveal(Duration.zero);
  }

  @override
  void didUpdateWidget(McTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != _keys.length) {
      _keys = _newKeys();
    }
    // Only a change of the selection scrolls the bar: a parent rebuild with
    // the same index must not snap it back.
    if (widget.currentIndex != oldWidget.currentIndex) {
      _reveal(McMotion.normal);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls the bar's own row (never an ancestor) so the selected tab is
  /// centred, when the row scrolls at all.
  void _reveal(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final object = _keys[widget.currentIndex].currentContext
          ?.findRenderObject();
      if (object == null || !object.attached) {
        return;
      }
      unawaited(
        _controller.position.ensureVisible(
          object,
          alignment: 0.5,
          duration: McA11y.duration(context, duration),
          curve: McMotion.standard,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    // High contrast draws the divider at full strength.
    final divider = McA11y.highContrast(context)
        ? p.outline
        : p.outline.withAlpha(80);
    final row = Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: _TabRow(
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            KeyedSubtree(
              key: _keys[i],
              child: _TabItem(
                key: widget.tabs[i].key,
                label: widget.tabs[i].label,
                selected: i == widget.currentIndex,
                onTap: () => widget.onChanged(i),
              ),
            ),
        ],
      ),
    );
    // `Align` with a height factor: under tight parent constraints (a page
    // body) the divider still sits right under the tabs.
    return Align(
      alignment: AlignmentDirectional.topCenter,
      heightFactor: 1,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: divider, width: McTabBar.dividerHeight),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.hasBoundedWidth
                ? SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: row,
                    ),
                  )
                // Unbounded: as wide as the tabs; a horizontal scroll view
                // cannot be given an infinite width.
                : row,
          ),
        ),
      ),
    );
  }
}

/// A row that gives each child its natural width plus an equal share of the
/// free space up to the incoming minimum width (so the tabs fill the bar when
/// they fit), and is as high as its tallest child. Unlike a `Row` it needs no
/// bounded width, and unlike `Expanded` it never shrinks a tab below its
/// label.
class _TabRow extends MultiChildRenderObjectWidget {
  const _TabRow({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTabRow();
}

class _TabRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTabRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TabRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TabRowParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TabRowParentData) {
      child.parentData = _TabRowParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    var total = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      total += c.getMaxIntrinsicWidth(height);
    }
    return total;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    var h = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      h = math.max(h, c.getMaxIntrinsicHeight(double.infinity));
    }
    return h;
  }

  Size _layout(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    required bool position,
  }) {
    final children = <RenderBox>[];
    for (var c = firstChild; c != null; c = childAfter(c)) {
      children.add(c);
    }
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);
    final natural = [for (final c in children) layoutChild(c, loose).width];
    final total = natural.fold<double>(0, (a, b) => a + b);
    final width = constraints.constrainWidth(total);
    final extra = children.isEmpty
        ? 0.0
        : math.max(0.0, width - total) / children.length;
    var height = 0.0;
    var x = 0.0;
    for (var i = 0; i < children.length; i++) {
      final size = layoutChild(
        children[i],
        BoxConstraints(
          minWidth: natural[i] + extra,
          maxWidth: natural[i] + extra,
          maxHeight: constraints.maxHeight,
        ),
      );
      height = math.max(height, size.height);
      if (position) {
        (children[i].parentData! as _TabRowParentData).offset = Offset(x, 0);
      }
      x += size.width;
    }
    return constraints.constrain(Size(math.max(width, x), height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild, position: false);

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild, position: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return Semantics(
      role: SemanticsRole.tab,
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: mcMinTapTarget,
            minHeight: McTabBar.height,
            maxHeight: McTabBar.height,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? p.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: McSpacing.lg),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: McTabBar.labelMaxScale),
                  style: McTypeScale.label.copyWith(
                    color: selected ? p.primary : p.onSurfaceMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
