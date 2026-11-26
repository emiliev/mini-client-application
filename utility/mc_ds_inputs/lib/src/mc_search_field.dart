import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_inputs/src/field_style.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A search field: a search icon, a clear button that exists only while there
/// is text, and a "search" keyboard action.
///
/// **Controlled.** The owner holds the [controller]. Clearing empties it,
/// calls `onChanged('')` and keeps the focus in the field. Debouncing is not
/// this widget's job: `onChanged` fires on every edit, and the feature
/// debounces (`mc_paging`'s `DebouncedQuery`).
///
/// **Width.** Needs a bounded width; with an unbounded one it is
/// [mcFieldUnboundedWidth] wide.
class McSearchField extends StatefulWidget {
  const McSearchField({
    required this.controller,
    required this.label,
    required this.clearLabel,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;

  /// The placeholder while empty and the accessible name ("Search characters").
  final String label;

  /// The accessible name of the clear button ("Clear search").
  final String clearLabel;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<McSearchField> createState() => _McSearchFieldState();
}

class _McSearchFieldState extends State<McSearchField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return boundedFieldWidth(
      Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) => Semantics(
            label: widget.label,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: p.primary,
              style: McTypeScale.body.copyWith(
                color: widget.enabled ? p.onSurface : p.onSurfaceMuted,
              ),
              decoration:
                  mcFieldDecoration(
                    context,
                    enabled: widget.enabled,
                    pill: true,
                    hint: ExcludeSemantics(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McTypeScale.body.copyWith(
                          color: p.onSurfaceMuted,
                        ),
                      ),
                    ),
                    prefix: const ExcludeSemantics(child: Icon(Icons.search)),
                    suffix: value.text.isEmpty || !widget.enabled
                        ? null
                        : McIconButton(
                            icon: Icons.close,
                            semanticLabel: widget.clearLabel,
                            onPressed: _clear,
                          ),
                  ).copyWith(
                    fillColor: widget.enabled ? p.surfaceVariant : p.surface,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
