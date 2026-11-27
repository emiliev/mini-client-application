import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// How long a toast stays without an action.
const mcToastDuration = Duration(seconds: 4);

/// How long a toast with an action stays (the user needs time to read it and
/// reach the action).
const mcToastActionDuration = Duration(seconds: 8);

/// The one optional action of a toast ("Undo").
class McToastAction {
  const McToastAction({required this.label, required this.onPressed});

  final String label;

  /// Called once; the toast closes with it.
  final VoidCallback onPressed;
}

/// Shows a toast: a DS-styled floating `SnackBar` with an optional single
/// [action]. A new toast **replaces** the current one at once (it does not
/// queue behind it).
///
/// The message is announced to a screen reader as a live region. The toast
/// stays [mcToastDuration], or [mcToastActionDuration] when it has an
/// [action] (unless [duration] is given); an action never keeps it open for
/// ever. The action wraps below the message when they do not fit on one line
/// (a `SnackBarAction` overflows at large text), is at least 44 pt and
/// fires once.
///
/// Needs a [ScaffoldMessenger] above [context] (a `MaterialApp` has one).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMcToast(
  BuildContext context,
  String message, {
  McToastAction? action,
  Duration? duration,
}) {
  final p = context.mcPalette;
  final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: McSpacing.xs,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: McTypeScale.body.copyWith(color: p.surface),
            ),
          ),
          if (action != null) _ToastActionButton(action: action),
        ],
      ),
      duration:
          duration ??
          (action == null ? mcToastDuration : mcToastActionDuration),
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.onSurface,
      elevation: McElevation.medium,
      margin: const EdgeInsets.all(McSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: McRadius.mdAll),
    ),
  );
}

class _ToastActionButton extends StatefulWidget {
  const _ToastActionButton({required this.action});

  final McToastAction action;

  @override
  State<_ToastActionButton> createState() => _ToastActionButtonState();
}

class _ToastActionButtonState extends State<_ToastActionButton> {
  bool _fired = false;

  void _press() {
    if (_fired) {
      return;
    }
    _fired = true;
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
    widget.action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return TextButton(
      onPressed: _press,
      style: TextButton.styleFrom(
        foregroundColor: p.surface,
        minimumSize: const Size(mcMinTapTarget, mcMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: McSpacing.md),
        textStyle: McTypeScale.label,
      ),
      child: Text(widget.action.label, textAlign: TextAlign.center),
    );
  }
}
