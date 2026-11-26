import 'package:flutter/material.dart';
import 'package:mc_ds_inputs/src/mc_chip.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One choice of a [McChipGroup].
@immutable
class McChipOption<T> {
  const McChipOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Chips that wrap onto as many lines as they need. It is controlled: the
/// owner holds the selection and reacts to [onChanged].
///
/// - [McChipGroup.single]: at most one chip is selected. Tapping another chip
///   selects it (and so deselects the previous one); tapping the selected one
///   deselects it only with [allowDeselect], else it stays selected.
/// - [McChipGroup.multi]: tapping toggles a chip; [onChanged] gets a new set
///   (the one passed in is never mutated).
///
/// A null [onChanged] disables every chip. Works with an unbounded width (the
/// chips then sit in one run).
class McChipGroup<T> extends StatelessWidget {
  const McChipGroup.single({
    required this.options,
    required T? selected,
    required ValueChanged<T?>? onChanged,
    this.allowDeselect = false,
    super.key,
  }) : _single = selected,
       _multi = null,
       _onSingle = onChanged,
       _onMulti = null,
       isMulti = false;

  const McChipGroup.multi({
    required this.options,
    required Set<T> selected,
    required ValueChanged<Set<T>>? onChanged,
    super.key,
  }) : _single = null,
       _multi = selected,
       _onSingle = null,
       _onMulti = onChanged,
       allowDeselect = true,
       isMulti = true;

  final List<McChipOption<T>> options;

  /// Single-select only: whether tapping the selected chip clears it.
  final bool allowDeselect;

  /// True for [McChipGroup.multi].
  final bool isMulti;

  final T? _single;
  final Set<T>? _multi;
  final ValueChanged<T?>? _onSingle;
  final ValueChanged<Set<T>>? _onMulti;

  bool _isSelected(T value) =>
      isMulti ? _multi!.contains(value) : _single == value;

  ValueChanged<bool>? _handler(T value) {
    if (isMulti) {
      final onChanged = _onMulti;
      if (onChanged == null) {
        return null;
      }
      return (on) => onChanged(
        on ? {..._multi!, value} : ({..._multi!}..remove(value)),
      );
    }
    final onChanged = _onSingle;
    if (onChanged == null) {
      return null;
    }
    return (on) {
      if (on) {
        onChanged(value);
      } else if (allowDeselect) {
        onChanged(null);
      }
    };
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: McSpacing.sm,
    children: [
      for (final o in options)
        McChip(
          key: ValueKey<T>(o.value),
          label: o.label,
          icon: o.icon,
          selected: _isSelected(o.value),
          exclusive: !isMulti,
          onSelected: _handler(o.value),
        ),
    ],
  );
}
