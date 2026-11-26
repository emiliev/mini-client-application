import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_inputs/src/field_style.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// An integer stepper: a decrease button, the value and an increase button.
///
/// It is controlled: the owner holds [value] and reacts to [onChanged] with
/// the new value, which is clamped to `[min, max]`. At [min] the decrease
/// button is disabled, at [max] the increase button. A null [onChanged]
/// disables both. A [value] outside `[min, max]` is shown as it is (the
/// owner's business); the buttons then step back towards the range.
///
/// **Semantics.** One group named [label] whose value is the current number;
/// inside it, the two buttons are named [decreaseLabel] and [increaseLabel]
/// (a disabled one says so). The drawn number is excluded, so it is not read
/// twice. Each button is 44 x 44 pt.
///
/// **Size.** The row is as wide as its content; a long number scales down
/// instead of overflowing.
class McStepper extends StatelessWidget {
  const McStepper({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.valueText,
    super.key,
  }) : assert(min <= max, 'min must not exceed max'),
       assert(step > 0, 'step must be positive');

  final int value;
  final ValueChanged<int>? onChanged;

  /// What the number counts ("Quantity"): the group's accessible name.
  final String label;

  /// The accessible names of the buttons ("Decrease quantity").
  final String decreaseLabel;
  final String increaseLabel;
  final int min;
  final int max;
  final int step;

  /// How the number is written and read; `value.toString()` when null.
  final String Function(int value)? valueText;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final text = (valueText ?? (v) => '$v')(value);
    final change = onChanged;
    final canDecrease = change != null && value > min;
    final canIncrease = change != null && value < max;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      value: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: McRadius.mdAll,
          border: Border.all(
            color: change == null ? mcDisabledOutline(context) : p.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            McIconButton(
              icon: Icons.remove,
              semanticLabel: decreaseLabel,
              onPressed: canDecrease
                  ? () => change(_clamp(value - step))
                  : null,
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: McSpacing.xs,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: McTypeScale.headline.copyWith(
                          color: change == null
                              ? p.onSurfaceMuted
                              : p.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            McIconButton(
              icon: Icons.add,
              semanticLabel: increaseLabel,
              onPressed: canIncrease
                  ? () => change(_clamp(value + step))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  int _clamp(int v) => v < min ? min : (v > max ? max : v);
}
