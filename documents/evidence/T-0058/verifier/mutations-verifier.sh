#!/bin/bash
# T-0058 mutation check: each mutation of mc_ds_overlays, the overlay steps
# and the sign-in sheet must make a test fail (a mutation that survives means
# a test does not prove its claim).
#
# Verdicts, counted separately:
#   KILLED    the target ended with `FAILED in` (a test failed);
#   SURVIVED  the target PASSED;
#   BROKEN    `Build did NOT complete` (or no verdict at all): the mutant did
#             not compile, analyse or format, so it proves nothing. Counted as
#             a defect of the mutant, never as a kill.
#   NOT APPLIED  the mutation did not change the file.
# Equivalent mutants found and dropped (not run): the dialog's destructive
# button and the toast's action button with `minimumSize: Size.zero` (Material
# pads a TextButton / OutlinedButton to 48 pt by `MaterialTapTargetSize.padded`
# anyway, so the declared 44 pt minimum never decides), and `liveRegion` on the
# toast text (the SnackBar is a live region itself; a test pins that).
# The unmutated tree must pass first (positive control).
#
# Safety: the script REFUSES to run on a dirty tree (a restore is
# `git checkout -- .`, which would eat uncommitted work), sets its restore
# trap BEFORE the first edit, restores after every mutant and verifies the
# tree is clean again.
#   MC_TASK=T-0058 MC_ROLE=engineer documents/evidence/T-0058/engineer/mutations.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TASK="${MC_TASK:-T-0058}"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OB:-/tmp/mc-ob-$TASK-$ROLE}"
bz() { tool/bazelw --output_base="$OB" "$@"; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the working tree is dirty (commit or remove the changes first)"
  git status --porcelain | head
  exit 2
fi

restore() { git checkout -q -- . ; }
trap restore EXIT   # set before the first edit

LIB=utility/mc_ds_overlays/lib/src
STEPS=utility/mc_test_steps/lib/src
SIGN=app/wiring/app_core/lib/src/sign_in/fixture_sign_in_sheet.dart
T=//utility/mc_ds_overlays:overlays_test
G=//utility/mc_ds_overlays:golden_test
ST=//utility/mc_test_steps:overlay_steps_test
SI=//app/wiring/app_core:sign_in_sheet_test
killed=0; survived=0; broken=0; notapplied=0
rc=0

run() { bz test "$1" --nocache_test_results --test_output=errors 2>&1 | tr '\r' '\n'; }

for tgt in "$T" "$ST" "$SI"; do
  base="$(run "$tgt")"
  if ! grep -q "PASSED in" <<< "$base"; then echo "BASELINE FAILS: $tgt"; tail -20 <<< "$base"; exit 1; fi
  echo "baseline $tgt: PASS"
done

# mutate <target> <name> <file> <python expression on s; `re` and `nth` exist>
mutate() {
  local target="$1" name="$2" file="$3" expr="$4"
  python3 -I - "$file" "$expr" <<'EOF'
import re, sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()

def nth(s, a, b, n=1):
    i = -1
    for _ in range(n):
        i = s.find(a, i + 1)
        if i < 0:
            return s
    return s[:i] + b + s[i + len(a):]

t = eval(expr)
if t == s:
    print("MUTATION DID NOT CHANGE THE FILE"); sys.exit(3)
open(p, "w").write(t)
EOF
  if [[ $? -ne 0 ]]; then echo "$name: NOT APPLIED"; notapplied=$((notapplied+1)); rc=1; restore; return; fi
  fvm dart format "$file" > /dev/null
  local out; out="$(run "$target")"
  if grep -q "Build did NOT complete" <<< "$out"; then
    echo "$name: BROKEN (does not build: $(grep -a -m1 -E 'error|Error|info -|warning -' <<< "$out" | sed 's/^ *//' | cut -c1-100))"
    broken=$((broken+1)); rc=1
  elif grep -q "FAILED in" <<< "$out"; then
    echo "$name: KILLED ($(grep -a -m1 '  FAIL ' <<< "$out" | sed 's/^ *//' | cut -c1-100))"
    killed=$((killed+1))
  elif grep -q "PASSED in" <<< "$out"; then
    echo "$name: SURVIVED"; survived=$((survived+1)); rc=1
  else
    echo "$name: BROKEN (no verdict)"; broken=$((broken+1)); rc=1
  fi
  restore
  [[ -z "$(git status --porcelain)" ]] || { echo "RESTORE FAILED"; rc=1; git status --porcelain | head -3; }
}

DLG=$LIB/mc_dialog.dart
SHT=$LIB/mc_sheet.dart
MNU=$LIB/mc_menu_button.dart
TST=$LIB/mc_toast.dart
TIP=$LIB/mc_tooltip.dart

# --- confirm and dialog: return values ----------------------------------------
mutate $T "confirm answers false" $DLG "nth(s, '.pop(true)', '.pop(false)')"
mutate $T "cancel answers true" $DLG "nth(s, '.pop(false)', '.pop(true)')"
mutate $T "sheet ignores the nearest option" $SHT "nth(s, 'useRootNavigator: useRootNavigator,', 'useRootNavigator: true,', 1)"
mutate $T "sheet is not dismissible" $SHT "s.replace('isDismissible: isDismissible,', 'isDismissible: false,')"
mutate $T "sheet ignores the bottom inset" $SHT "s.replace('bottom: keyboard == 0,', 'bottom: false,')"
mutate $T "toast queues instead of replacing" $TST "s.replace('..removeCurrentSnackBar()', '')"
mutate $T "toast action can fire twice" $TST "re.sub(r'if \\(_fired\\) \\{\\s*return;\\s*\\}', '', s)"
mutate $T "sheet ignores the keyboard" $SHT "s.replace('padding: EdgeInsets.only(bottom: keyboard),', 'padding: EdgeInsets.zero,')"
mutate $T "handle offered although the sheet is not dismissible" $SHT "s.replace('dismissible: isDismissible && enableDrag,', 'dismissible: true,')"
mutate $T "handle ignores isDismissible: false" $SHT "s.replace('dismissible: isDismissible && enableDrag,', 'dismissible: enableDrag,')"
mutate $ST "confirm step taps cancel" $STEPS/interaction/i_confirm_the_dialog.dart "s.replace('mcConfirmButtonKey', 'mcCancelButtonKey')"
mutate $T "menu does not report the pick" $MNU "s.replace('onSelected: widget.onSelected,', 'onSelected: (_) {},')"
mutate $SI "sign-in sheet allows a drag while busy" $SIGN "s.replace('onVerticalDragStart: _busy ? (_) {} : null,', 'onVerticalDragStart: null,')"
echo "--- verifier's own mutations ---"
mutate $T "V1 showMcDialog default barrierDismissible false" $DLG "s.replace('bool barrierDismissible = true,', 'bool barrierDismissible = false,')"
mutate $T "V2 keyboard inset halved" $SHT "s.replace('EdgeInsets.only(bottom: keyboard)', 'EdgeInsets.only(bottom: keyboard * 0.5)')"
mutate $T "V3 safe-area bottom kept under keyboard" $SHT "s.replace('bottom: keyboard == 0,', 'bottom: true,')"
mutate $T "V4 handle dismissible = isDismissible || enableDrag" $SHT "s.replace('isDismissible && enableDrag,', 'isDismissible || enableDrag,')"
mutate $T "V5 route isDismissible always true" $SHT "s.replace('isDismissible: isDismissible,', 'isDismissible: true,')"
mutate $T "V6 plain toast 4s -> 2s" $TST "s.replace('Duration(seconds: 4)', 'Duration(seconds: 2)')"
mutate $T "V7 handle pops instead of maybePop" $SHT "s.replace('Navigator.of(context).maybePop()', 'Navigator.of(context).pop()')"
mutate $T "V8 selected choice row ignores taps" $SHT "s.replace('onTap: () => onPicked(option.value),', 'onTap: option.value == selected ? () {} : () => onPicked(option.value),')"
mutate $T "V9 menu inverts root navigator" $MNU "s.replace('useRootNavigator: widget.useRootNavigator,', 'useRootNavigator: !widget.useRootNavigator,')"
mutate $T "V10 toast hide instead of remove" $TST "s.replace('..removeCurrentSnackBar()', '..hideCurrentSnackBar()')"
echo "killed=$killed survived=$survived broken=$broken notapplied=$notapplied"
