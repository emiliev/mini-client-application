#!/bin/bash
# T-0044 mutation check: each mutation of mc_ds_inputs must make a test fail
# (a mutation that survives means a test does not prove its claim).
# The unmutated tree must pass first (positive control). Each mutation is
# restored afterwards, and the restore is verified with `git diff --quiet`.
# The script REFUSES to run when the package's lib has uncommitted edits,
# because restoring a mutation is a `git checkout` of that folder.
#   MC_TASK=T-0044 MC_ROLE=engineer documents/evidence/T-0044/engineer/mutations.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TASK="${MC_TASK:-T-0044}"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OB:-/tmp/mc-ob-$TASK-$ROLE}"
bz() { tool/bazelw --output_base="$OB" "$@"; }
LIB=utility/mc_ds_inputs/lib/src
T=//utility/mc_ds_inputs:inputs_test
G=//utility/mc_ds_inputs:golden_test
rc=0

if ! git diff --quiet -- "$LIB" || ! git diff --cached --quiet -- "$LIB"; then
  echo "REFUSING TO RUN: $LIB has uncommitted edits (commit them first)"
  exit 2
fi

restore() { git checkout -- "$LIB"; }
trap restore EXIT

run() { bz test "${1:-$T}" --nocache_test_results --test_output=errors 2>&1 | tr '\r' '\n'; }

base="$(run "$T")"
if ! grep -q "PASSED" <<< "$base"; then echo "BASELINE FAILS"; echo "$base" | tail -20; exit 1; fi
echo "baseline (behaviour and semantics tests): PASS"
baseg="$(run "$G")"
if ! grep -q "PASSED" <<< "$baseg"; then echo "GOLDEN BASELINE FAILS"; echo "$baseg" | tail -20; exit 1; fi
echo "baseline (goldens): PASS"

# mutate <target> <name> <file> <python expression on s; `re` is available>
mutate() {
  local target="$1" name="$2" file="$3" expr="$4"
  python3 -I - "$file" "$expr" <<'EOF'
import re, sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
if t == s:
    print("MUTATION DID NOT CHANGE THE FILE"); sys.exit(3)
open(p, "w").write(t)
EOF
  if [[ $? -ne 0 ]]; then echo "$name: NOT APPLIED"; rc=1; restore; return; fi
  fvm dart format "$LIB" > /dev/null
  out="$(run "$target")"
  # Killed only by a failing test, not by a build, format or analyze error.
  if grep -q "^  FAIL " <<< "$out"; then
    echo "$name: KILLED ($(grep -a -m1 '  FAIL ' <<< "$out" | sed 's/^ *//' | cut -c1-110))"
  else
    echo "$name: SURVIVED"; rc=1
  fi
  restore
  git diff --quiet -- "$LIB" || { echo "RESTORE FAILED"; rc=1; }
}

FLD=$LIB/field_style.dart
TXT=$LIB/mc_text_field.dart
SRC=$LIB/mc_search_field.dart
CHP=$LIB/mc_chip.dart
GRP=$LIB/mc_chip_group.dart
SEG=$LIB/mc_segmented.dart
STP=$LIB/mc_stepper.dart

# --- AC1: layout --------------------------------------------------------------
mutate $T "AC1 unbounded width not handled" $FLD "re.sub(r'constraints.hasBoundedWidth\\s*\\?', 'true ?', s)"
mutate $T "AC1 chip label not flexible (overflows at 3x)" $CHP \
  "re.sub(r'Flexible\(\s*child:', 'Padding(padding: EdgeInsets.zero, child:', s)"
mutate $T "AC1 segment label not flexible (overflows)" $SEG \
  "re.sub(r'Flexible\(\s*child:', 'Padding(padding: EdgeInsets.zero, child:', s)"
mutate $T "AC1 segment label scale uncapped" $SEG "s.replace('.clamp(maxScaleFactor: labelMaxScale),', ',')"
mutate $T "AC1 stepper number does not scale down (overflow)" $STP \
  "s.replace('fit: BoxFit.scaleDown', 'fit: BoxFit.none')"

# --- AC2: behaviour -----------------------------------------------------------
mutate $T "AC2 search clear always visible" $SRC "s.replace('value.text.isEmpty || !widget.enabled', '!widget.enabled')"
mutate $T "AC2 search clear does not call onChanged('')" $SRC "s.replace(\"widget.onChanged?.call('');\", '')"
mutate $T "AC2 search clear does not empty the field" $SRC "s.replace('widget.controller.clear();', '')"
mutate $T "AC2 search clear drops the focus" $SRC "s.replace('_focus.requestFocus();', '')"
mutate $T "AC2 search action is not 'search'" $SRC "s.replace('TextInputAction.search', 'TextInputAction.done')"
mutate $T "AC2 search onSubmitted dropped" $SRC "s.replace('onSubmitted: widget.onSubmitted,', '')"
mutate $T "AC2 search autofocus dropped" $SRC "s.replace('autofocus: widget.autofocus,', '')"
mutate $T "AC2 text onChanged dropped" $TXT "s.replace('onChanged: onChanged,', '')"
mutate $T "AC2 text maxLength dropped" $TXT "s.replace('maxLength: maxLength,', '')"
mutate $T "AC2 text obscure dropped" $TXT "s.replace('obscureText: obscureText,', '')"
mutate $T "AC2 text action dropped" $TXT "s.replace('textInputAction: textInputAction,', '')"
mutate $T "AC2 text suffix dropped" $FLD "s.replace('suffixIcon: suffix,', '')"
mutate $T "AC2 text disabled ignored" $TXT "s.replace('enabled: enabled,\n          autofocus', 'autofocus')"
mutate $T "AC2 single chip does not deselect the previous" $GRP \
  "s.replace('selected: _isSelected(o.value),', 'selected: _isSelected(o.value) || o.value == \"a\",')"
mutate $T "AC2 single chip reports nothing on select" $GRP "s.replace('onChanged(value);', '')"
mutate $T "AC2 single deselect always allowed" $GRP "s.replace('else if (allowDeselect)', 'else if (true)')"
mutate $T "AC2 multi set mutated in place" $GRP "s.replace('({..._multi!}..remove(value))', '(_multi!..remove(value))')"
mutate $T "AC2 multi never adds" $GRP "s.replace('on ? {..._multi!, value} :', 'on ? {..._multi!} :')"
mutate $T "AC2 chip group without handler stays enabled" $GRP \
  "s.replace('if (onChanged == null) {\n        return null;\n      }\n      return (on) => onChanged(', 'if (onChanged == null) {\n        return (_) {};\n      }\n      return (on) => onChanged(')"
mutate $T "AC2 chip reports the old value" $CHP "s.replace('onSelected!(!selected)', 'onSelected!(selected)')"
mutate $T "AC2 stepper does not clamp" $STP "s.replace('_clamp(value - step)', 'value - step').replace('_clamp(value + step)', 'value + step')"
mutate $T "AC2 stepper decrease never disabled" $STP "s.replace('change != null && value > min', 'change != null')"
mutate $T "AC2 stepper increase never disabled" $STP "s.replace('change != null && value < max', 'change != null')"
mutate $T "AC2 stepper ignores step" $STP "s.replace('value - step', 'value - 1').replace('value + step', 'value + 1')"
mutate $T "AC2 stepper valueText ignored" $STP "re.sub(r'final text = [^;]*;', 'final text = value.toString();', s)"
mutate $T "AC2 segmented reports the selected index" $SEG "s.replace('onChanged!(i)', 'onChanged!(selectedIndex)')"

# --- AC3: semantics -----------------------------------------------------------
mutate $T "AC3 error not a live region" $FLD "s.replace('liveRegion: true', 'liveRegion: false')"
mutate $T "AC3 error text dropped" $FLD "s.replace('              errorText,\\n', \"              '',\\n\")"
mutate $T "AC3 text field label dropped" $FLD "s.replace('labelText: label,', '')"
mutate $T "AC3 search label dropped" $SRC "s.replace('label: widget.label,\n            child: TextField', 'child: TextField')"
mutate $T "AC3 clear button unlabelled" $SRC "s.replace('semanticLabel: widget.clearLabel', 'semanticLabel: \"\"')"
mutate $T "AC3 chip selected flag dropped" $CHP "s.replace('selected: selected,\n        enabled', 'enabled')"
mutate $T "AC3 chip button flag dropped" $CHP "s.replace('button: true,', '')"
mutate $T "AC3 chip exclusive flag dropped" $CHP "s.replace('inMutuallyExclusiveGroup: exclusive ? true : null,', '')"
mutate $T "AC3 chip group not exclusive" $GRP "s.replace('exclusive: !isMulti,', 'exclusive: false,')"
mutate $T "AC3 chip tap target below 44" $CHP "re.sub(r'minHeight: (mcMinTapTarget|20)', 'minHeight: 0', s)"
mutate $T "AC3 chip disabled has a tap action" $CHP "s.replace('onTap: enabled ? () => onSelected!(!selected) : null,\n        excludeSemantics', 'onTap: () => onSelected?.call(!selected),\n        excludeSemantics')"
mutate $T "AC3 segment selected flag dropped" $SEG "s.replace('selected: selected,\n      enabled', 'enabled')"
mutate $T "AC3 segment button flag dropped" $SEG "s.replace('button: true,', '')"
mutate $T "AC3 segment group flag dropped" $SEG "s.replace('inMutuallyExclusiveGroup: true,', '')"
mutate $T "AC3 segment tap target below 44" $SEG "s.replace('minHeight: mcMinTapTarget,', 'minHeight: 10,')"
mutate $T "AC3 stepper group label dropped" $STP "s.replace('label: label,', '')"
mutate $T "AC3 stepper group value dropped" $STP "s.replace('value: text,', '')"
mutate $T "AC3 stepper number read twice" $STP "s.replace('child: ExcludeSemantics(', 'child: Semantics(')"
mutate $T "AC3 stepper decrease label dropped" $STP "s.replace('semanticLabel: decreaseLabel', 'semanticLabel: \"\"')"
mutate $T "AC3 stepper increase label dropped" $STP "s.replace('semanticLabel: increaseLabel', 'semanticLabel: \"\"')"
mutate $T "AC3 disabled outline dimmed in high contrast" $FLD \
  "s.replace('McA11y.highContrast(context) ? p.outline : p.outline.withAlpha(110)', 'p.outline.withAlpha(110)')"
mutate $T "AC3 selected text colour invisible (contrast)" $SEG "s.replace('? p.onPrimary', '? p.primary')"
mutate $T "AC3 chip selected text invisible (contrast)" $CHP "s.replace('? p.onPrimary', '? p.primary')"
mutate $T "AC3 muted hint colour too faint (contrast)" $FLD \
  "s.replace('final muted = McTypeScale.body.copyWith(color: p.onSurfaceMuted);', 'final muted = McTypeScale.body.copyWith(color: p.surfaceVariant);')"

# --- AC1: goldens (visual states) ----------------------------------------------
mutate $G "AC1 golden: selected chip fill removed" $CHP "s.replace('final fill = selected', 'final fill = false')"
mutate $G "AC1 golden: disabled selected text invisible" $CHP \
  "s.replace('final foreground = selected\n        ? p.onPrimary\n        : (enabled ? p.onSurface : p.onSurfaceMuted);', 'final foreground = !enabled ? p.onSurfaceMuted : selected ? p.onPrimary : p.onSurface;')"
mutate $G "AC1 golden: focused border not primary" $FLD "s.replace('border(hasError ? p.error : p.primary, 2)', 'border(hasError ? p.error : p.outline, 1)')"
mutate $G "AC1 golden: error border not error colour" $FLD "s.replace('errorBorder: border(p.error, 2)', 'errorBorder: border(p.outline, 1)')"
mutate $G "AC1 golden: segmented selection fill hidden" $SEG "s.replace('child: Ink(\n        color: fill,', 'child: Ink(\n        color: p.surface,')"

echo
[[ $rc -eq 0 ]] && echo "ALL MUTATIONS KILLED" || echo "SOME MUTATIONS SURVIVED OR FAILED TO APPLY"
exit $rc
