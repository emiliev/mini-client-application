import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Width given to a text field that is laid out with an unbounded width (in a
/// `Row` without `Expanded`): a `TextField` cannot size itself.
const double mcFieldUnboundedWidth = 280;

/// Gives [field] a width when the incoming one is unbounded.
Widget boundedFieldWidth(Widget field) => LayoutBuilder(
  builder: (context, constraints) => constraints.hasBoundedWidth
      ? field
      : SizedBox(width: mcFieldUnboundedWidth, child: field),
);

/// The border colour for a disabled control. High contrast draws it at full
/// strength: an alpha would drop it below the contrast the mode promises.
Color mcDisabledOutline(BuildContext context) {
  final p = context.mcPalette;
  return McA11y.highContrast(context) ? p.outline : p.outline.withAlpha(110);
}

/// The decoration shared by the text and search fields.
InputDecoration mcFieldDecoration(
  BuildContext context, {
  required bool enabled,
  bool pill = false,
  String? label,
  Widget? hint,
  String? helperText,
  String? errorText,
  Widget? prefix,
  Widget? suffix,
}) {
  final p = context.mcPalette;
  final hasError = errorText != null;
  final radius = pill ? BorderRadius.circular(McRadius.pill) : McRadius.mdAll;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: color, width: width),
  );
  final muted = McTypeScale.body.copyWith(color: p.onSurfaceMuted);
  const slot = BoxConstraints(
    minWidth: mcMinTapTarget,
    minHeight: mcMinTapTarget,
  );
  return InputDecoration(
    labelText: label,
    hint: hint,
    helperText: helperText,
    // A widget, not `errorText`, so the error can be a live region: a screen
    // reader announces it when it appears.
    error: errorText == null
        ? null
        : Semantics(
            liveRegion: true,
            child: Text(
              errorText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: McTypeScale.caption.copyWith(color: p.error),
            ),
          ),
    helperMaxLines: 3,
    prefixIcon: prefix,
    suffixIcon: suffix,
    prefixIconConstraints: slot,
    suffixIconConstraints: slot,
    filled: true,
    fillColor: enabled ? p.surface : p.surfaceVariant,
    labelStyle: muted,
    floatingLabelStyle: McTypeScale.caption.copyWith(
      color: hasError ? p.error : p.onSurfaceMuted,
    ),
    hintStyle: muted,
    helperStyle: McTypeScale.caption.copyWith(color: p.onSurfaceMuted),
    counterStyle: McTypeScale.caption.copyWith(color: p.onSurfaceMuted),
    prefixIconColor: p.onSurfaceMuted,
    suffixIconColor: p.onSurfaceMuted,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: McSpacing.lg,
      vertical: McSpacing.md,
    ),
    enabledBorder: border(hasError ? p.error : p.outline, hasError ? 2 : 1),
    focusedBorder: border(hasError ? p.error : p.primary, 2),
    errorBorder: border(p.error, 2),
    focusedErrorBorder: border(p.error, 2),
    disabledBorder: border(mcDisabledOutline(context), 1),
  );
}
