import 'package:flutter/widgets.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Fixed empty space on both axes, so it works in a `Row` or a `Column`.
class McGap extends StatelessWidget {
  const McGap(this.size, {super.key});

  const McGap.xs({super.key}) : size = McSpacing.xs;
  const McGap.sm({super.key}) : size = McSpacing.sm;
  const McGap.md({super.key}) : size = McSpacing.md;
  const McGap.lg({super.key}) : size = McSpacing.lg;
  const McGap.xl({super.key}) : size = McSpacing.xl;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size);
}

/// Common padding values built from the spacing tokens.
abstract final class McInsets {
  static const EdgeInsets screen = EdgeInsets.all(McSpacing.lg);
  static const EdgeInsets card = EdgeInsets.all(McSpacing.md);
  static const EdgeInsets horizontal = EdgeInsets.symmetric(
    horizontal: McSpacing.lg,
  );
  static const EdgeInsets vertical = EdgeInsets.symmetric(
    vertical: McSpacing.lg,
  );
}
