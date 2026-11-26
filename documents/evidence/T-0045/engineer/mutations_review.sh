# Sourced by mutations.sh: mutations for the code-review round (T-0045).
RV=$F/lib/src/validators.dart
m R-pattern-group $VAL $RV "r'(?<![\\s\\S])(?:' + regex.pattern + r')(?![\\s\\S])" "r'(?<![\\s\\S])' + regex.pattern + r'(?![\\s\\S])'"
m R-pattern-start $VAL $RV "r'(?<![\\s\\S])(?:'" "r'(?:'"
m R-pattern-end $VAL $RV "r')(?![\\s\\S])'" "r')'"
m R-pattern-case $VAL $RV 'caseSensitive: regex.isCaseSensitive,' 'caseSensitive: true,'
m R-pattern-dotall $VAL $RV 'dotAll: regex.isDotAll,' 'dotAll: false,'
m R-min-graphemes $VAL $RV 'value.characters.length >= min' 'value.length >= min'
m R-max-graphemes $VAL $RV 'value.characters.length <= max' 'value.length <= max'
m R-set-submitting $FORM $FC '    _spec(name);
    if (_state.isSubmitting) {
      return;
    }' '    _spec(name);'
m R-touch-submitting $FORM $FC '    targets.forEach(_spec);
    if (_state.isSubmitting) {
      return;
    }' '    targets.forEach(_spec);'
m R-fieldof-value $FORM $FST 'value: f.value as T?,' 'value: null,'
m R-fieldof-touched $FORM $FST 'touched: f.touched,' 'touched: false,'
m R-complete-touch-first $WIZ $WC '        touchCurrentStep();
        return null;' '        _form.touchAll();
        return null;'
m R-can-next-completed $WIZ $WC '!isLast && isCurrentStepValid && !isCompleting && !isCompleted;' '!isLast && isCurrentStepValid && !isCompleting;'
m R-next-completed $WIZ $WC '        _state.isCompleting ||
        _state.isCompleted) {' '        _state.isCompleting) {'
m R-touch-current $WIZ $WC '      _form.touchAll(names: _state.stepFields[_state.stepIndex]);' '      _form.touchAll();'
m R-scope-busy $DT $SC 'McFormScope(enabled: !isSubmitting, child: body)' 'McFormScope(enabled: true, child: body)'
m R-blocked-busy $DT $SC '                          !isSubmitting &&
' ''
m R-blocked-hint-scaffold $DT $SC '                      hint: blockedHint,' '                      hint: null,'
m R-blocked-hint-stepper $DT $WS '                        hint: blockedHint,' '                        hint: null,'
m R-blocked-active $DT $WS 'active: onNext == null && onBlockedNext != null,' 'active: onBlockedNext != null,'
m R-blocked-completing $DT $WS '    onBlockedNext: state.isCompleting || state.isCompleted
        ? null
        : onBlockedNext,' '    onBlockedNext: onBlockedNext,'
m R-group-enabled $DT $FG '      enabled: enabled,' '      enabled: true,'
m R-scope-narrow $DT $D/lib/src/mc_form_scope.dart 'McFormScope(enabled: enabled && enabledOf(context), child: child)' 'McFormScope(enabled: enabled, child: child)'
m R-field-enabled $DT $FT 'enabled: widget.enabled && McFormScope.enabledOf(context),' 'enabled: widget.enabled,'
m R-sync-guard $DT $FT '    if (old.field.value == widget.field.value) {' '    if (false) {'
m R-selection $DT $FT 'baseOffset: clamp(selection.baseOffset),' 'baseOffset: 0,'
m R-reported $DT $FT '      if (!_reported) {' '      if (true) {'
m R-reported-rearm $DT $FT '      _reported = false;
    }
    // Only' '    }
    // Only'
m R-reported-init $DT $FT 'late bool _reported = widget.field.touched;' 'late bool _reported = false;'
