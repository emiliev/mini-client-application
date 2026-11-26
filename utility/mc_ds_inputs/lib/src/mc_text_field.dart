import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mc_ds_inputs/src/field_style.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A labelled text field.
///
/// **Controlled.** The owner holds the [controller]; changing its text
/// updates the field, and [onChanged] is called only for edits the user makes
/// (never for a programmatic change), so there is no feedback loop.
///
/// **Errors.** A non-null [errorText] replaces the helper text, turns the
/// border and the floating label to the error colour, and is announced to
/// screen readers when it appears (a live region).
///
/// **Affixes.** [prefix] and [suffix] sit in slots at least 44 x 44 pt; a
/// tappable one (a "show password" button) must be at least that big itself.
///
/// **Width.** Needs a bounded width; with an unbounded one (a `Row` without
/// `Expanded`) it is [mcFieldUnboundedWidth] wide. Works without a `Scaffold`.
class McTextField extends StatelessWidget {
  const McTextField({
    required this.controller,
    required this.label,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  }) : assert(
         !obscureText || maxLines == 1,
         'an obscured field has a single line',
       );

  final TextEditingController controller;

  /// The label: placeholder while empty, then floats above the text. It is
  /// also the field's accessible name.
  final String label;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;

  /// Maximum length; shows a "n/max" counter and stops typing at the limit.
  final int? maxLength;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// False draws the field disabled (not focusable, not editable).
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return boundedFieldWidth(
      Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          cursorColor: p.primary,
          style: McTypeScale.body.copyWith(
            color: enabled ? p.onSurface : p.onSurfaceMuted,
          ),
          decoration: mcFieldDecoration(
            context,
            enabled: enabled,
            label: label,
            hint: hint == null
                ? null
                : Text(
                    hint!,
                    style: McTypeScale.body.copyWith(
                      color: context.mcPalette.onSurfaceMuted,
                    ),
                  ),
            helperText: helperText,
            errorText: errorText,
            prefix: prefix,
            suffix: suffix,
          ),
        ),
      ),
    );
  }
}
