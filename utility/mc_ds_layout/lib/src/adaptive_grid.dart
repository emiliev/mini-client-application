import 'package:flutter/widgets.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

import 'breakpoints.dart';

/// A non-scrolling grid whose column count follows the available width:
/// 2 (compact), 3 (medium) or 4 (expanded). Put it inside a scroll view.
class McAdaptiveGrid extends StatelessWidget {
  const McAdaptiveGrid({
    required this.children,
    this.spacing = McSpacing.md,
    this.childAspectRatio = 1,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> children;
  final double spacing;
  final double childAspectRatio;
  final EdgeInsets padding;

  /// The column count for [width].
  static int columnsFor(double width) => McWidthClass.of(width).columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          padding: padding,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}
