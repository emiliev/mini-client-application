import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A bottom-sheet card: a drag handle, then a [title] and a [child] that
/// scroll together, and the bottom safe-area inset.
///
/// It brings no route: show it with [showMcSheet]. It needs a bounded height
/// (a route or a `Scaffold` body gives one); the body scrolls when the sheet
/// is taller than the screen, so large text never overflows.
///
/// **Semantics.** The card scopes and names its route with [title]. The
/// drag handle is a 44 pt button named [dismissLabel] that closes the sheet
/// through `Navigator.maybePop`, so a `PopScope` that refuses to pop (a
/// sheet that is busy) is respected.
class McSheet extends StatelessWidget {
  const McSheet({
    required this.title,
    required this.dismissLabel,
    required this.child,
    super.key,
  });

  final String title;

  /// The accessible name of the drag handle's dismiss action.
  final String dismissLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Material(
        color: p.surface,
        elevation: McElevation.high,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(McRadius.lg),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DragHandle(dismissLabel: dismissLabel),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    McSpacing.lg,
                    0,
                    McSpacing.lg,
                    McSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: McTypeScale.headline.copyWith(
                            color: p.onSurface,
                          ),
                        ),
                      ),
                      const McGap.sm(),
                      DefaultTextStyle.merge(
                        style: McTypeScale.body.copyWith(color: p.onSurface),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.dismissLabel});

  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return Semantics(
      label: dismissLabel,
      button: true,
      onTap: () => Navigator.of(context).maybePop(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          height: mcMinTapTarget,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.outline,
                borderRadius: McRadius.smAll,
              ),
              child: const SizedBox(width: 36, height: McSpacing.xs),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a bottom sheet and answers what it was popped with, or null when it
/// was dismissed (barrier tap, swipe down, system back).
///
/// [builder] normally returns an [McSheet]. It is pushed on the **root**
/// navigator, so it covers the whole flow; pass `useRootNavigator: false` to
/// keep it inside the nearest (nested) navigator. [dismissLabel] is the
/// accessible name of the barrier (null uses the platform's localised one).
Future<T?> showMcSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool isDismissible = true,
  bool enableDrag = true,
  String? dismissLabel,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  backgroundColor: Colors.transparent,
  elevation: 0,
  barrierLabel: dismissLabel,
  builder: builder,
);

/// One choice of [showMcChoiceSheet].
class McChoiceOption<T> {
  const McChoiceOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Shows [options] in a sheet and answers the tapped value, or null when the
/// sheet is dismissed. Single-select: the option equal to [selected] shows a
/// check and is announced as selected; tapping it answers its value again.
Future<T?> showMcChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required String dismissLabel,
  required List<McChoiceOption<T>> options,
  T? selected,
  bool useRootNavigator = true,
}) => showMcSheet<T>(
  context,
  useRootNavigator: useRootNavigator,
  dismissLabel: dismissLabel,
  builder: (sheetContext) => McSheet(
    title: title,
    dismissLabel: dismissLabel,
    child: McChoiceList<T>(
      options: options,
      selected: selected,
      onPicked: (value) => Navigator.of(sheetContext).pop(value),
    ),
  ),
);

/// The rows of a choice sheet: one tappable row per option, at least 44 pt
/// tall, a check on the selected one. Public so a sheet can host it next to
/// other content; [showMcChoiceSheet] is the normal way in.
class McChoiceList<T> extends StatelessWidget {
  const McChoiceList({
    required this.options,
    required this.selected,
    required this.onPicked,
    super.key,
  });

  final List<McChoiceOption<T>> options;
  final T? selected;
  final ValueChanged<T> onPicked;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final option in options)
        _ChoiceRow(
          option: option,
          reserveIcon: options.any((o) => o.icon != null),
          selected: option.value == selected,
          onTap: () => onPicked(option.value),
        ),
    ],
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.option,
    required this.reserveIcon,
    required this.selected,
    required this.onTap,
  });

  final McChoiceOption<dynamic> option;

  /// Some option has an icon: rows without one keep the icon's space, so the
  /// labels line up.
  final bool reserveIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final scaler = MediaQuery.textScalerOf(context);
    final iconSize = scaler.scale(24);
    return Semantics(
      label: option.label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: mcMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: McSpacing.sm),
            child: Row(
              children: [
                if (reserveIcon) ...[
                  SizedBox.square(
                    dimension: iconSize,
                    child: option.icon == null
                        ? null
                        : Icon(option.icon, size: iconSize, color: p.onSurface),
                  ),
                  const McGap.md(),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    style: McTypeScale.body.copyWith(
                      color: p.onSurface,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (selected) ...[
                  const McGap.md(),
                  Icon(Icons.check, size: iconSize, color: p.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
