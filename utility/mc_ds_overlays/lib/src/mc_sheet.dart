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
/// **Keyboard.** The card is lifted by the keyboard's inset, so a text field
/// in it stays visible and the body scrolls above the keyboard.
///
/// **Semantics.** The route scopes itself; the [title] is one node: the
/// heading that also names the route. The drag handle is a 44 pt button named
/// [dismissLabel] that closes the sheet through `Navigator.maybePop`, so a
/// `PopScope` that refuses to pop (a sheet that is busy) is respected. In a
/// sheet shown with `isDismissible: false` or `enableDrag: false` the handle
/// is only a picture: no tap, no name.
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
    // The keyboard: lift the card above it. The body is a scroll view in a
    // bounded column, so what no longer fits scrolls and the handle and the
    // title stay put. The safe-area inset is the keyboard's job while it is up.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
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
          bottom: keyboard == 0,
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
                      // One node: the heading, and the route's name.
                      Semantics(
                        header: true,
                        namesRoute: true,
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

/// Tells an [McSheet] whether the route may be dismissed by the user, so its
/// handle does not offer what the barrier and the drag refuse.
class _McSheetScope extends InheritedWidget {
  const _McSheetScope({required this.dismissible, required super.child});

  final bool dismissible;

  static bool dismissibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_McSheetScope>()
          ?.dismissible ??
      true;

  @override
  bool updateShouldNotify(_McSheetScope old) => dismissible != old.dismissible;
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.dismissLabel});

  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final bar = SizedBox(
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
    );
    if (!_McSheetScope.dismissibleOf(context)) {
      // Not dismissible: the handle is a picture, with no tap and no name.
      return ExcludeSemantics(child: bar);
    }
    return Semantics(
      label: dismissLabel,
      button: true,
      onTap: () => Navigator.of(context).maybePop(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: bar,
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
  builder: (sheetContext) => _McSheetScope(
    dismissible: isDismissible && enableDrag,
    child: Builder(builder: builder),
  ),
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
