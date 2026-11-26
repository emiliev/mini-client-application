import 'dart:async';

import 'package:flutter/material.dart';
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
/// Tabs share the width when they fit; otherwise the row scrolls
/// horizontally, so five tabs at a large text scale never overflow. Each tab
/// is at least [mcMinTapTarget] square, and is a selectable tab for screen
/// readers.
class McTabBar extends StatelessWidget {
  const McTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
    super.key,
  }) : assert(tabs.length >= 2, 'a tab bar has at least two tabs');

  final List<McTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Minimum height of a tab.
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.outline.withAlpha(80))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            // The tab-bar node is inside the scroll view, so its children
            // are the tabs (a tab bar node may only hold tab nodes).
            child: Semantics(
              role: SemanticsRole.tabBar,
              container: true,
              explicitChildNodes: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _TabItem(
                      key: tabs[i].key,
                      label: tabs[i].label,
                      selected: i == currentIndex,
                      onTap: () => onChanged(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
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
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) {
      _reveal(Duration.zero);
    }
  }

  @override
  void didUpdateWidget(_TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _reveal(McMotion.normal);
    }
  }

  /// Scrolls the selected tab into view when the bar scrolls (a no-op when it
  /// does not).
  void _reveal(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: McA11y.duration(context, duration),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return Semantics(
      role: SemanticsRole.tab,
      selected: widget.selected,
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: mcMinTapTarget,
            minHeight: McTabBar.height,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? p.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: McSpacing.lg,
                vertical: McSpacing.sm,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: McTypeScale.label.copyWith(
                    color: widget.selected ? p.primary : p.onSurfaceMuted,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
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
