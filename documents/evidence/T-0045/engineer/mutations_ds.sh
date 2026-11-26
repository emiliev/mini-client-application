# Sourced by mutations.sh: the mc_ds_forms mutations (T-0045-AC3).
DT=//$D:forms_test
DG=//$D:golden_test
SC=$D/lib/src/mc_form_scaffold.dart
WS=$D/lib/src/mc_wizard_stepper.dart
FG=$D/lib/src/mc_field_group.dart
FT=$D/lib/src/mc_form_text_field.dart

m S-busy-blocks $DT $SC 'onPressed: isSubmitting ? null : onSubmit,' 'onPressed: onSubmit,'
m S-busy-label $DT $SC 'label: isSubmitting ? busyLabel : submitLabel,' 'label: submitLabel,'
m S-spinner $DT $SC '                  if (isSubmitting)
' '                  if (false)
'
m S-error-live $DT $SC '                  liveRegion: true,
' ''
m S-error-hidden $DT $SC 'if (error != null) ...[' 'if (error != null && false) ...['
m S-keyboard $DT $SC 'keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,' 'keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,'
m S-scroll-stays $DT $SC '          Expanded(
            child: SingleChildScrollView(' '          Flexible(
            child: SingleChildScrollView('
m T-state-next $DT $WS '(state.isLast ? state.canComplete : state.canGoNext)' '(state.isLast ? state.canComplete : true)'
m T-state-finish $DT $WS '(state.isLast ? state.canComplete : state.canGoNext)' '(state.isLast ? true : state.canGoNext)'
m T-state-label $DT $WS 'nextLabel: state.isLast ? finishLabel : nextLabel,' 'nextLabel: nextLabel,'
m T-state-back $DT $WS 'onBack: state.canGoBack ? onBack : null,' 'onBack: onBack,'
m T-live $DT $WS '                liveRegion: true,
' ''
m T-label $DT $WS 'final label = stepLabel(currentStep + 1, stepCount);' 'final label = stepLabel(currentStep, stepCount);'
m T-segments $DT $WS 'color: i <= currentStep' 'color: i < currentStep'
m T-back-wired $DT $WS 'onPressed: onBack,
                        expand' 'onPressed: onNext,
                        expand'
m T-next-wired $DT $WS 'onPressed: onNext,
                        expand' 'onPressed: onBack,
                        expand'
m G-header $DT $FG 'header: true,' 'header: false,'
m G-description $DT $FG 'if (description != null) ...[' 'if (false) ...['
m F-visible $DT $FT 'final error = widget.field.visibleError;' 'final error = widget.field.error;'
m F-sync $DT $FT 'if (value != _controller.text) {' 'if (false) {'
m F-touch $DT $FT '      _hadFocus = true;' '      _hadFocus = false;'
m F-initial $DT $FT 'text: widget.field.value ?? '"''"',' 'text: '"''"','
m F-message $DT $FT 'errorText: error == null ? null : widget.errorMessage(error),' 'errorText: null,'
m F-changed $DT $FT 'onChanged: widget.onChanged,' 'onChanged: null,'
m GOLD-segment-colour $DG $WS 'color: i <= currentStep
                                    ? p.primary' 'color: i <= currentStep
                                    ? p.error'
m GOLD-bar-border $DG $SC 'shape: Border(top: BorderSide(color: p.outline)),' 'shape: Border(top: BorderSide(color: p.error)),'
m GOLD-group-gap $DG $FG 'for (final child in children) ...[const McGap.md(), child],' 'for (final child in children) ...[const McGap.xl(), child],'
