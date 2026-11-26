#!/bin/bash
# T-0045 mutation check: every validator rule and wizard/form behaviour is
# mutated once. Each mutation must make the named test target FAIL with a
# failing test (Bazel exit 3; a mutation that survives, or that only breaks the
# build, proves nothing). The unmutated tree must pass first (baseline).
# Each mutation is restored with `git checkout` of its file and the restore is
# verified. The script REFUSES to run when a mutated file has uncommitted
# edits, and it replaces EXACTLY ONE occurrence (a pattern that matches zero or
# several times is reported as NOT APPLIED and fails the run).
#
#   MC_TASK=T-0045 MC_ROLE=engineer documents/evidence/T-0045/engineer/mutations.sh
#   MC_ONLY="V-required-blank W-next-blocked" ...   runs only the named mutations
#
# Output base /tmp/mc-ob-$MC_TASK-$MC_ROLE; log /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log
# (also printed). Exit 0 only if every mutation was applied and killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK (e.g. T-0045)}"
: "${MC_ROLE:?set MC_ROLE (engineer or verifier)}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log"
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

F=utility/mc_forms
D=utility/mc_ds_forms
VAL=//$F:validators_test
FORM=//$F:form_controller_test
WIZ=//$F:wizard_controller_test
FILES=(
  $F/lib/src/validators.dart $F/lib/src/field_spec.dart $F/lib/src/field_state.dart
  $F/lib/src/form_state.dart $F/lib/src/form_controller.dart $F/lib/src/wizard_controller.dart
)
# mc_ds_forms files join the list once the package exists.
if [[ -d $D/lib ]]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(find $D/lib -name '*.dart' | sort)
fi
for f in "${FILES[@]}"; do
  if ! git diff --quiet -- "$f" || ! git diff --cached --quiet -- "$f"; then
    say "REFUSING TO RUN: $f has uncommitted edits (commit them first)"
    exit 2
  fi
done

killed=0; survived=0; notapplied=0
SURVIVORS=()
# m <id> <target> <file> <old> <new>
m() {
  local id="$1" target="$2" file="$3" old="$4" new="$5"
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then return; fi
  if ! OLD="$old" NEW="$new" python3 -I - "$file" <<'PY'
import os, sys
p = sys.argv[1]
s = open(p).read()
old, new = os.environ["OLD"], os.environ["NEW"]
if s.count(old) != 1:
    sys.stderr.write("count=%d\n" % s.count(old))
    sys.exit(1)
open(p, "w").write(s.replace(old, new))
PY
  then
    say "NOT APPLIED  $id ($file)"; notapplied=$((notapplied+1)); SURVIVORS+=("$id(not applied)"); return
  fi
  bz test "$target" --test_output=errors > "/tmp/mc-$MC_TASK-$MC_ROLE-mut-$id.log" 2>&1
  local rc=$?
  git checkout -q -- "$file"
  if ! git diff --quiet -- "$file"; then say "RESTORE FAILED for $file"; exit 3; fi
  if [[ $rc -eq 3 ]]; then
    say "KILLED       $id -> $target"; killed=$((killed+1))
  else
    say "SURVIVED     $id -> $target (bazel exit $rc)"; survived=$((survived+1)); SURVIVORS+=("$id")
  fi
}

say "== baseline (unmutated) =="
if ! bz test //$F/... $( [[ -d $D ]] && echo "//$D/..." ) > "/tmp/mc-$MC_TASK-$MC_ROLE-baseline.log" 2>&1; then
  say "BASELINE FAILED: see /tmp/mc-$MC_TASK-$MC_ROLE-baseline.log"; exit 1
fi
say "baseline passes"

V=$F/lib/src/validators.dart
FS=$F/lib/src/field_spec.dart
ST=$F/lib/src/field_state.dart
FST=$F/lib/src/form_state.dart
FC=$F/lib/src/form_controller.dart
WC=$F/lib/src/wizard_controller.dart

# --- validators (AC1) ---
m V-required-null $VAL $V 'value == null ||
        (value is String' 'false ||
        (value is String'
m V-required-blank $VAL $V 'value.trim().isEmpty' 'value.isEmpty'
m V-required-iterable $VAL $V '(value is Iterable<Object?> && value.isEmpty) ||' 'false ||'
m V-required-map $VAL $V '(value is Map<Object?, Object?> && value.isEmpty);' 'false;'
m V-required-code $VAL $V 'empty ? const FieldError(ValidationCode.required) : null' 'empty ? const FieldError(ValidationCode.invalid) : null'
m V-minlength-boundary $VAL $V 'value.characters.length >= min' 'value.characters.length > min'
m V-minlength-empty $VAL $V 'value == null || value.isEmpty || value.characters.length >= min' 'value == null || value.characters.length >= min'
m V-minlength-limit $VAL $V 'FieldError(ValidationCode.tooShort, min: min)' 'FieldError(ValidationCode.tooShort)'
m V-maxlength-boundary $VAL $V 'value.characters.length <= max' 'value.characters.length < max'
m V-maxlength-limit $VAL $V 'FieldError(ValidationCode.tooLong, max: max)' 'FieldError(ValidationCode.tooLong)'
m V-pattern-whole $VAL $V 'return anchored.hasMatch(value) ? null : FieldError(code);' 'return null;'
m V-pattern-empty $VAL $V '      if (value == null || value.isEmpty) {
        return null;
      }
      return anchored' '      if (value == null) {
        return null;
      }
      return anchored'
m V-pattern-code $VAL $V 'FieldError(code);' 'FieldError(ValidationCode.patternMismatch);'
m V-range-below $VAL $V 'if (min != null && value < min) {' 'if (min != null && value <= min) {'
m V-range-above $VAL $V 'if (max != null && value > max) {' 'if (max != null && value >= max) {'
m V-range-below-code $VAL $V 'return FieldError(ValidationCode.belowMin, min: min, max: max);' 'return FieldError(ValidationCode.aboveMax, min: min, max: max);'
m V-range-above-code $VAL $V 'return FieldError(ValidationCode.aboveMax, min: min, max: max);' 'return FieldError(ValidationCode.belowMin, min: min, max: max);'
m V-range-inverted $VAL $V 'if (min != null && max != null && min > max) {' 'if (false) {'
m V-range-limits $VAL $V 'return FieldError(ValidationCode.belowMin, min: min, max: max);' 'return FieldError(ValidationCode.belowMin);'
m V-compose-order $VAL $V 'final copy = List<Validator<T>>.of(rules);' 'final copy = List<Validator<T>>.of(rules.reversed);'
m V-compose-copy $VAL $V 'final copy = List<Validator<T>>.of(rules);' 'final copy = rules;'
m V-matches $VAL $V 'value == values.get<Object>(other)
      ?' 'true
      ?'
m V-matches-code $VAL $V ': const FieldError(ValidationCode.mismatch);' ': const FieldError(ValidationCode.invalid);'
m V-requiredwhen $VAL $V 'condition(values) ? Validators.required<T>()(value) : null' 'Validators.required<T>()(value)'
m V-fielddef-validators $VAL $FS 'for (final v in validators) {' 'for (final v in <Validator<T>>[]) {'
m V-fielddef-cross $VAL $FS 'for (final v in crossValidators) {' 'for (final v in <CrossValidator<T>>[]) {'
m V-formvalues-unknown $VAL $F/lib/src/form_values.dart "if (!_values.containsKey(name)) {" "if (false) {"

# --- field and form state, form controller (AC2) ---
m F-dirty $FORM $ST 'bool get dirty => value != initial;' 'bool get dirty => true;'
m F-visible $FORM $ST 'touched ? error : null' 'error'
m F-touch-idempotent $FORM $ST '          error: error,
          touched: true,
        );' '          error: error,
          touched: false,
        );'
m F-equality $FORM $ST '      other.touched == touched;' '      true;'
m F-valid $FORM $FST 'fields.values.every((f) => f.isValid)' 'fields.values.any((f) => f.isValid)'
m F-visible-errors $FORM $FST 'if (e.value.visibleError != null) e.key: e.value.visibleError!,' 'if (e.value.error != null) e.key: e.value.error!,'
m F-cross-revalidate $FORM $FC 'e.value.withError(_specs[e.key]!.check(e.value.value, values))' 'e.value'
m F-touch-names $FORM $FC 'e.key: targets.contains(e.key) ? e.value.touch() : e.value,' 'e.key: e.value.touch(),'
m F-touch-emit $FORM $FC 'if (!_sameFields(next)) {' 'if (true) {'
m F-set-unknown $FORM $FC '    _spec(name);
    if (_state.isSubmitting) {' '    if (_state.isSubmitting) {'
m F-dup-names $FORM $FC 'if (map.containsKey(f.name)) {' 'if (false) {'
m F-reset-guard $FORM $FC 'if (_state.isSubmitting) {
      return;
    }
    final values' 'if (false) {
      return;
    }
    final values'
m F-reset-values $FORM $FC '              value: e.value.initial,
              initial: e.value.initial,
              error: e.value.check(e.value.initial, values),' '              value: _state.fields[e.key]!.value,
              initial: e.value.initial,
              error: e.value.check(e.value.initial, values),'
m F-submit-double $FORM $FC 'if (_disposed || _state.isSubmitting) {' 'if (_disposed) {'
m F-submit-invalid $FORM $FC '    if (!_state.isValid) {
      return null;
    }' '    if (false) {
      return null;
    }'
m F-submit-touch $FORM $FC '    touchAll();
    if (!_state.isValid)' '    if (!_state.isValid)'
m F-submit-error-status $FORM $FC '      _emit(_withStatus(SubmitStatus.idle));
      rethrow;' '      rethrow;'
m F-submit-exception $FORM $FC '    } on Exception catch (error) {
      result = failure(ApiFailure.from(error));
    } on Object {' '    } on Object {'
m F-submit-failure $FORM $FC 'submitStatus: SubmitStatus.failed,
          submitFailure: error,' 'submitStatus: SubmitStatus.failed,'
m F-submit-result $FORM $FC 'submitStatus: SubmitStatus.succeeded,
          submitResult: value,' 'submitStatus: SubmitStatus.succeeded,'
m F-edit-clears-failure $FORM $FC '? SubmitStatus.idle' '? SubmitStatus.failed'
m F-disposed-emit $FORM $FC 'if (!_disposed) {
      onState(next);' 'if (true) {
      onState(next);'

# --- wizard (AC2, P1-14 AC4) ---
m W-next-blocked $WIZ $WC 'if (!_state.isCurrentStepValid) {
      touchCurrentStep' 'if (false) {
      touchCurrentStep'
m W-next-touch $WIZ $WC '      touchCurrentStep();
      return false;' '      return false;'
m W-next-touch-all $WIZ $WC '_form.touchAll(names: _state.stepFields[_state.stepIndex]);' '_form.touchAll();'
m W-next-last $WIZ $WC '        _state.isLast ||
' ''
m W-next-completing $WIZ $WC '        _state.isCompleting ||
' ''
m W-back-guard $WIZ $WC 'if (_disposed || !_state.canGoBack) {' 'if (_disposed) {'
m W-back-completing $WIZ $WC 'bool get canGoBack => !isFirst && !isCompleting && !isCompleted;' 'bool get canGoBack => !isFirst;'
m W-step-errors $WIZ $WC 'for (final name in stepFields[index])' 'for (final name in stepFields[0])'
m W-is-last $WIZ $WC 'bool get isLast => stepIndex == stepCount - 1;' 'bool get isLast => stepIndex == stepCount;'
m W-can-next $WIZ $WC '      !isLast && isCurrentStepValid && !isCompleting && !isCompleted;' '      !isLast && !isCompleting && !isCompleted;'
m W-can-complete $WIZ $WC '      isLast && isCurrentStepValid && !isCompleting && !isCompleted;' '      isLast && !isCompleting && !isCompleted;'
m W-complete-once $WIZ $WC 'if (_disposed || _state.isCompleting || _state.isCompleted) {
      return null;' 'if (_disposed || _state.isCompleting) {
      return null;'
m W-complete-jump $WIZ $WC '        _goTo(i);
' ''
m W-complete-validate $WIZ $WC '      if (!_state.isStepValid(i)) {' '      if (false) {'
m W-empty-steps $WIZ $WC 'if (steps.isEmpty) {' 'if (false) {'
m W-keeps-step $WIZ $WC 'void _onForm(McFormState form) => _emit(_build(form, _state.stepIndex));' 'void _onForm(McFormState form) => _emit(_build(form, 0));'
m W-disposed-form $WIZ $WC '    _disposed = true;
    _form.dispose();' '    _disposed = true;'
m W-result $WIZ $WC 'R? get result => isCompleted ? form.submitResult as R? : null;' 'R? get result => null;'
m W-failure $WIZ $WC 'ApiFailure? get failure => form.submitFailure;' 'ApiFailure? get failure => null;'

# mc_ds_forms mutations are appended by the second half of the task.
if [[ -f "$(dirname "$0")/mutations_ds.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/mutations_ds.sh"
fi

if [[ -f "$(dirname "$0")/mutations_review.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/mutations_review.sh"
fi

say ""
say "killed=$killed survived=$survived not-applied=$notapplied"
if (( survived + notapplied > 0 )); then say "SURVIVORS: ${SURVIVORS[*]}"; exit 1; fi
say "ALL MUTATIONS KILLED"
