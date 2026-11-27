import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Keys of the two buttons [showMcConfirm] draws, for tests and the BDD
/// steps ("I confirm the dialog", "I cancel the dialog").
const mcConfirmButtonKey = Key('mc_overlays.confirm');
const mcCancelButtonKey = Key('mc_overlays.cancel');

/// How an action of an [McDialog] is drawn.
enum McDialogActionKind {
  /// A quiet text button (Cancel).
  normal,

  /// The filled, brand-coloured button: the answer we hope for.
  primary,

  /// An outlined button in the error colour: an action that cannot be undone.
  /// (Not filled: the brand's primary colour is itself red.)
  destructive,
}

/// One button of an [McDialog]. [onPressed] usually pops the dialog with an
/// answer (`Navigator.of(context).pop(value)`); a null one disables it.
class McDialogAction {
  const McDialogAction({
    required this.label,
    required this.onPressed,
    this.kind = McDialogActionKind.normal,
    this.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final McDialogActionKind kind;
  final Key? key;
}

/// A dialog card: a title, a body and one to three actions stacked below.
///
/// It brings no route: show it with [showMcDialog] (or [showMcConfirm]).
/// The whole card scrolls when it is taller than the screen, so large text
/// never overflows. **Semantics:** the card scopes its route and [title] is
/// one node, the heading that also names the route, so a screen reader
/// announces the title once when the dialog opens.
/// The actions are plain buttons of at least 44 pt.
///
/// It uses no `LayoutBuilder` (F-0043), so it is safe in any intrinsic-size
/// context.
class McDialog extends StatelessWidget {
  const McDialog({
    required this.title,
    required this.body,
    required this.actions,
    super.key,
  }) : assert(
         actions.length >= 1 && actions.length <= 3,
         'a dialog has one to three actions',
       );

  final String title;
  final Widget body;
  final List<McDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: McElevation.high,
      shape: const RoundedRectangleBorder(borderRadius: McRadius.lgAll),
      insetPadding: const EdgeInsets.all(McSpacing.xl),
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(McSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One node: the heading, and the route's name.
              Semantics(
                header: true,
                namesRoute: true,
                child: Text(
                  title,
                  style: McTypeScale.headline.copyWith(color: p.onSurface),
                ),
              ),
              const McGap.md(),
              DefaultTextStyle.merge(
                style: McTypeScale.body.copyWith(color: p.onSurface),
                child: body,
              ),
              const McGap.xl(),
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const McGap.sm(),
                _ActionButton(action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action);

  final McDialogAction action;

  @override
  Widget build(BuildContext context) {
    switch (action.kind) {
      case McDialogActionKind.normal:
        return McButton(
          key: action.key,
          label: action.label,
          variant: McButtonVariant.tertiary,
          onPressed: action.onPressed,
        );
      case McDialogActionKind.primary:
        return McButton(
          key: action.key,
          label: action.label,
          onPressed: action.onPressed,
        );
      case McDialogActionKind.destructive:
        final p = context.mcPalette;
        return OutlinedButton(
          key: action.key,
          onPressed: action.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: p.error,
            disabledForegroundColor: p.onSurfaceMuted,
            side: BorderSide(
              color: action.onPressed == null ? p.surfaceVariant : p.error,
              width: 2,
            ),
            minimumSize: const Size(mcMinTapTarget, mcMinTapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: McSpacing.lg,
              vertical: McSpacing.sm,
            ),
            shape: const RoundedRectangleBorder(borderRadius: McRadius.mdAll),
            textStyle: McTypeScale.label,
          ),
          child: Text(action.label, textAlign: TextAlign.center),
        );
    }
  }
}

/// Shows a dialog and answers what it was popped with, or null when it was
/// dismissed (barrier tap, system back).
///
/// [builder] normally returns an [McDialog]. It is pushed on the **root**
/// navigator, so it covers the whole flow; pass `useRootNavigator: false` to
/// keep it inside the nearest (nested) navigator. [barrierLabel] is the
/// accessible name of the barrier (what a screen reader says for "tap to
/// dismiss"); null uses the platform's localised one.
Future<T?> showMcDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
  String? barrierLabel,
}) => showDialog<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  barrierDismissible: barrierDismissible,
  barrierLabel: barrierLabel,
  builder: builder,
);

/// Asks for a yes or no: `true` on confirm, `false` on cancel, a barrier tap
/// or system back. Never null.
///
/// [destructive] draws the confirm button in the error colour. The labels
/// are parameters because the design system has no localisation.
Future<bool> showMcConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  bool useRootNavigator = true,
  String? barrierLabel,
}) async {
  final answer = await showMcDialog<bool>(
    context,
    useRootNavigator: useRootNavigator,
    barrierLabel: barrierLabel,
    builder: (dialogContext) => McDialog(
      title: title,
      body: Text(message),
      actions: [
        McDialogAction(
          key: mcConfirmButtonKey,
          label: confirmLabel,
          kind: destructive
              ? McDialogActionKind.destructive
              : McDialogActionKind.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        McDialogAction(
          key: mcCancelButtonKey,
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return answer ?? false;
}
