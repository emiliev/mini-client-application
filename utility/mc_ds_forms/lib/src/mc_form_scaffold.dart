import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A form page: a scrollable [body] above a sticky submit bar.
///
/// The bar has three states: enabled ([onSubmit] set), disabled ([onSubmit]
/// null, for example while the form is invalid) and busy ([isSubmitting]:
/// a spinner and [busyLabel], and taps are blocked). A failed submit shows
/// [errorText] above the button and announces it. The caller passes every
/// string, already localised.
class McFormScaffold extends StatelessWidget {
  const McFormScaffold({
    required this.body,
    required this.submitLabel,
    required this.busyLabel,
    required this.onSubmit,
    this.isSubmitting = false,
    this.errorText,
    this.appBar,
    super.key,
  });

  /// The form fields. Scrolls; the keyboard dismisses on drag.
  final Widget body;

  final String submitLabel;

  /// The button label while [isSubmitting] (for example "Saving").
  final String busyLabel;

  /// Null disables the button.
  final VoidCallback? onSubmit;

  /// A submit is running: the button shows a spinner and ignores taps.
  final bool isSubmitting;

  /// Why the last submit failed. Announced to screen readers.
  final String? errorText;

  final PreferredSizeWidget? appBar;

  /// The submit button, for tests.
  static const submitKey = Key('mc_form_scaffold_submit');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: McInsets.screen,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: body,
            ),
          ),
          _SubmitBar(
            submitLabel: submitLabel,
            busyLabel: busyLabel,
            onSubmit: onSubmit,
            isSubmitting: isSubmitting,
            errorText: errorText,
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.submitLabel,
    required this.busyLabel,
    required this.onSubmit,
    required this.isSubmitting,
    required this.errorText,
  });

  final String submitLabel;
  final String busyLabel;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final error = errorText;
    return Material(
      color: p.surface,
      shape: Border(top: BorderSide(color: p.outline)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: McInsets.screen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Text(
                    error,
                    style: McTypeScale.caption.copyWith(color: p.error),
                  ),
                ),
                const McGap.sm(),
              ],
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  KeyedSubtree(
                    key: McFormScaffold.submitKey,
                    child: McButton(
                      label: isSubmitting ? busyLabel : submitLabel,
                      onPressed: isSubmitting ? null : onSubmit,
                      expand: true,
                    ),
                  ),
                  if (isSubmitting)
                    Padding(
                      padding: const EdgeInsets.only(left: McSpacing.lg),
                      child: ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onSurfaceMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
