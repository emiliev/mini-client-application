import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mc_ds_forms/src/mc_form_scope.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_forms/mc_forms.dart';

/// Turns a validation error into a message in the user's language. The kit
/// reports typed codes only; the feature owns the wording.
typedef McErrorMessage = String Function(FieldError error);

/// A text field bound to an `mc_forms` [FieldState].
///
/// It shows the [McTextField] with the field's value, and the error message
/// of `field.visibleError`: nothing until the field is touched (it lost
/// focus once, or the form was submitted or "Next" was tried), then the
/// current error under the field, announced by `McTextField`.
///
/// [onChanged] reports each user edit (wire it to `setValue`), and
/// [onTouched] reports the first loss of focus, once (wire it to `touch`). A
/// change of `field.value` from outside (a reset) updates the text without
/// calling [onChanged], and keeps the cursor where it was (clamped to the
/// new length). A rebuild with an unchanged value never touches the text.
/// The field is disabled while an enclosing [McFormScaffold] is busy or an
/// enclosing [McFieldGroup] is not enabled.
class McFormTextField extends StatefulWidget {
  const McFormTextField({
    required this.field,
    required this.label,
    required this.onChanged,
    required this.onTouched,
    required this.errorMessage,
    this.hint,
    this.helperText,
    this.obscureText = false,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.enabled = true,
    super.key,
  });

  final FieldState<String> field;
  final String label;
  final ValueChanged<String> onChanged;
  final VoidCallback onTouched;
  final McErrorMessage errorMessage;
  final String? hint;
  final String? helperText;
  final bool obscureText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  @override
  State<McFormTextField> createState() => _McFormTextFieldState();
}

class _McFormTextFieldState extends State<McFormTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.field.value ?? '',
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _hadFocus = false;

  /// `onTouched` was called (or the field already was touched). Sticky, so
  /// it fires once; a reset (touched goes back to false) re-arms it.
  late bool _reported = widget.field.touched;

  void _onFocus() {
    if (_focus.hasFocus) {
      _hadFocus = true;
    } else if (_hadFocus) {
      _hadFocus = false;
      if (!_reported) {
        _reported = true;
        widget.onTouched();
      }
    }
  }

  @override
  void didUpdateWidget(McFormTextField old) {
    super.didUpdateWidget(old);
    if (old.field.touched && !widget.field.touched) {
      _reported = false;
    }
    // Only a change of the field's value reaches the text: a parent rebuild
    // with a stale value must not overwrite what the user has typed since.
    if (old.field.value == widget.field.value) {
      return;
    }
    final value = widget.field.value ?? '';
    final current = _controller.value;
    if (value == current.text) {
      return;
    }
    int clamp(int offset) =>
        offset < 0 ? offset : math.min(offset, value.length);
    final selection = current.selection;
    final composing = current.composing;
    _controller.value = TextEditingValue(
      text: value,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: clamp(selection.baseOffset),
              extentOffset: clamp(selection.extentOffset),
              affinity: selection.affinity,
            )
          : TextSelection.collapsed(offset: value.length),
      composing: composing.isValid && composing.end <= value.length
          ? composing
          : TextRange.empty,
    );
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.field.visibleError;
    return McTextField(
      controller: _controller,
      focusNode: _focus,
      label: widget.label,
      onChanged: widget.onChanged,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: error == null ? null : widget.errorMessage(error),
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled && McFormScope.enabledOf(context),
    );
  }
}
