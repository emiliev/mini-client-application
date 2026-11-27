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

for tgt in "$T" "$G" "$ST" "$SI"; do
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
mutate $T "dismissal answers true" $DLG "s.replace('return answer ?? false;', 'return answer ?? true;')"
mutate $T "dismissal answers null (bang)" $DLG "s.replace('return answer ?? false;', 'return answer!;')"
mutate $T "destructive flag ignored" $DLG "s.replace('kind: destructive\n              ? McDialogActionKind.destructive\n              : McDialogActionKind.primary,', 'kind: McDialogActionKind.primary,')"
mutate $T "barrierDismissible ignored" $DLG "s.replace('barrierDismissible: barrierDismissible,', 'barrierDismissible: true,')"
mutate $T "dialog barrier label dropped" $DLG "nth(s, 'barrierLabel: barrierLabel,', '', 1)"
mutate $T "confirm barrier label dropped" $DLG "nth(s, 'barrierLabel: barrierLabel,', '', 2)"

# --- root vs nearest navigator ------------------------------------------------
mutate $T "dialog default is nearest navigator" $DLG "nth(s, 'bool useRootNavigator = true,', 'bool useRootNavigator = false,', 1)"
mutate $T "confirm default is nearest navigator" $DLG "nth(s, 'bool useRootNavigator = true,', 'bool useRootNavigator = false,', 2)"
mutate $T "dialog ignores the nearest option" $DLG "nth(s, 'useRootNavigator: useRootNavigator,', 'useRootNavigator: true,', 1)"
mutate $T "confirm does not pass the option on" $DLG "nth(s, 'useRootNavigator: useRootNavigator,', '', 2)"
mutate $T "sheet default is nearest navigator" $SHT "nth(s, 'bool useRootNavigator = true,', 'bool useRootNavigator = false,', 1)"
mutate $T "choice sheet default is nearest navigator" $SHT "nth(s, 'bool useRootNavigator = true,', 'bool useRootNavigator = false,', 2)"
mutate $T "sheet ignores the nearest option" $SHT "nth(s, 'useRootNavigator: useRootNavigator,', 'useRootNavigator: true,', 1)"
mutate $T "choice sheet does not pass the option on" $SHT "nth(s, 'useRootNavigator: useRootNavigator,', '', 2)"
mutate $T "menu default is nearest navigator" $MNU "s.replace('this.useRootNavigator = true,', 'this.useRootNavigator = false,')"
mutate $T "menu ignores the nearest option" $MNU "s.replace('useRootNavigator: widget.useRootNavigator,', 'useRootNavigator: true,')"

# --- dialog: semantics, layout, buttons ---------------------------------------
mutate $T "dialog does not name its route" $DLG "s.replace('namesRoute: true,', 'namesRoute: false,')"
mutate $T "dialog does not scope its route" $DLG "s.replace('scopesRoute: true,', 'scopesRoute: false,')"
mutate $T "dialog title is not a heading" $DLG "s.replace('header: true,', 'header: false,')"
mutate $T "dialog accepts any number of actions" $DLG "s.replace('actions.length >= 1 && actions.length <= 3', 'true')"
mutate $T "dialog does not scroll" $DLG "s.replace('child: SingleChildScrollView(', 'child: Padding(')"
mutate $T "destructive text is not the error colour" $DLG "s.replace('foregroundColor: p.error,', 'foregroundColor: p.primary,')"
mutate $T "cancel is not a quiet button" $DLG "s.replace('variant: McButtonVariant.tertiary,', 'variant: McButtonVariant.primary,')"

# --- sheet --------------------------------------------------------------------
mutate $T "sheet handle shorter than 44" $SHT "nth(s, 'height: mcMinTapTarget,', 'height: 20,', 1)"
mutate $T "sheet handle has no dismiss label" $SHT "s.replace('label: dismissLabel,\n      button: true,', 'label: \"\",\n      button: true,')"
mutate $T "sheet does not name its route" $SHT "s.replace('namesRoute: true,', 'namesRoute: false,')"
mutate $T "sheet barrier label dropped" $SHT "s.replace('barrierLabel: dismissLabel,', 'barrierLabel: null,')"
mutate $T "sheet is not dismissible" $SHT "s.replace('isDismissible: isDismissible,', 'isDismissible: false,')"
mutate $T "sheet cannot be dragged" $SHT "s.replace('enableDrag: enableDrag,', 'enableDrag: false,')"
mutate $T "sheet does not scroll" $SHT "s.replace('child: SingleChildScrollView(', 'child: Padding(')"
mutate $T "sheet ignores the bottom inset" $SHT "s.replace('bottom: keyboard == 0,', 'bottom: false,')"

# --- choice sheet: what it returns --------------------------------------------
mutate $T "choice answers null instead of the value" $SHT "s.replace('Navigator.of(sheetContext).pop(value)', 'Navigator.of(sheetContext).pop()')"
mutate $T "choice marks the wrong option" $SHT "s.replace('option.value == selected', 'option.value != selected')"
mutate $T "choice has no check" $SHT "s.replace('if (selected) ...[', 'if (!selected) ...[')"
mutate $T "choice does not announce the selection" $SHT "s.replace('selected: selected,\n      inMutuallyExclusiveGroup', 'selected: false,\n      inMutuallyExclusiveGroup')"
mutate $T "choice rows shorter than 44" $SHT "s.replace('BoxConstraints(minHeight: mcMinTapTarget)', 'BoxConstraints(minHeight: 0)')"
mutate $T "choice row is not a button" $SHT "nth(s, 'button: true,', 'button: false,', 2)"

# --- menu ---------------------------------------------------------------------
mutate $T "menu enables disabled items" $MNU "s.replace('enabled: item.enabled,', 'enabled: true,')"
mutate $T "menu does not report the pick" $MNU "s.replace('onSelected: widget.onSelected,', 'onSelected: (_) {},')"
mutate $T "menu destructive is not the error colour" $MNU "re.sub(r'item\\.destructive\\s*\\? p\\.error', 'item.destructive ? p.onSurface', s)"
mutate $T "menu disabled is not muted" $MNU "re.sub(r'!item\\.enabled\\s*\\? p\\.onSurfaceMuted', '!item.enabled ? p.onSurface', s)"
mutate $T "menu rows shorter than 44" $MNU "s.replace('height: mcMinTapTarget,', 'height: 0,')"
mutate $T "menu button has no accessible name" $MNU "s.replace('label: widget.semanticLabel,', 'label: \"\",')"
mutate $T "menu button is not openable by a screen reader" $MNU "s.replace('onTap: () => _menuKey.currentState?.showButtonMenu(),', 'onTap: null,')"

# --- toast --------------------------------------------------------------------
mutate $T "toast queues instead of replacing" $TST "s.replace('..removeCurrentSnackBar()', '')"
mutate $T "toast with an action is not longer" $TST "s.replace('action == null ? mcToastDuration : mcToastActionDuration', 'mcToastDuration')"
mutate $T "toast persists" $TST "s.replace('persist: false,', 'persist: true,')"
mutate $T "toast action can fire twice" $TST "re.sub(r'if \\(_fired\\) \\{\\s*return;\\s*\\}', '', s)"
mutate $T "toast action does not close the toast" $TST "re.sub(r'ScaffoldMessenger\\.of\\(\\s*context,?\\s*\\)\\.hideCurrentSnackBar\\([^;]*;', '', s)"
mutate $T "toast action never fires" $TST "s.replace('widget.action.onPressed();', '')"
mutate $T "toast ignores an explicit duration" $TST "s.replace('duration ??\n          (action', 'null ??\n          (action')"

# --- tooltip ------------------------------------------------------------------
mutate $T "tooltip shows on a plain tap" $TIP "s.replace('TooltipTriggerMode.longPress', 'TooltipTriggerMode.tap')"
mutate $T "tooltip has no message" $TIP "s.replace('message: message,', 'message: \"\",')"

# --- review round: keyboard, non-dismissible sheets, one title node, step ----
mutate $T "sheet ignores the keyboard" $SHT "s.replace('padding: EdgeInsets.only(bottom: keyboard),', 'padding: EdgeInsets.zero,')"
mutate $T "handle offered although the sheet is not dismissible" $SHT "s.replace('dismissible: isDismissible && enableDrag,', 'dismissible: true,')"
mutate $T "handle ignores isDismissible: false" $SHT "s.replace('dismissible: isDismissible && enableDrag,', 'dismissible: enableDrag,')"
mutate $T "handle ignores enableDrag: false" $SHT "s.replace('dismissible: isDismissible && enableDrag,', 'dismissible: isDismissible,')"
mutate $T "a standalone sheet has no handle action" $SHT "re.sub(r'\\?\\.dismissible \\?\\?\\s*true;', '?.dismissible ?? false;', s)"
mutate $T "sheet title is read twice (route label too)" $SHT "s.replace('scopesRoute: true,\n        explicitChildNodes: true,', 'scopesRoute: true,\n        explicitChildNodes: true,\n        label: title,')"
mutate $T "dialog title is read twice (route label too)" $DLG "s.replace('scopesRoute: true,\n        explicitChildNodes: true,', 'scopesRoute: true,\n        explicitChildNodes: true,\n        label: title,')"
mutate $G "real shadows off in the golden harness" utility/mc_test_utils/lib/src/golden.dart "s.replace('debugDisableShadows = !realShadows;', 'debugDisableShadows = true;')"
mutate $ST "choose step matches any text in the sheet again" $STEPS/interaction/i_choose_in_the_sheet.dart "re.sub(r'find\.byWidgetPredicate\(\(w\) => w is McChoiceList\)', 'find.byType(McSheet)', s)"

# --- goldens ------------------------------------------------------------------
mutate $G "choice rows do not line up (no reserved icon slot)" $SHT "s.replace('reserveIcon: options.any((o) => o.icon != null),', 'reserveIcon: false,')"
mutate $G "dialog corners" $DLG "nth(s, 'McRadius.lgAll', 'McRadius.mdAll', 1)"
mutate $G "toast colour" $TST "s.replace('backgroundColor: p.onSurface,', 'backgroundColor: p.primary,')"
mutate $G "sheet handle colour" $SHT "s.replace('color: p.outline,', 'color: p.onSurface,')"
mutate $G "menu border" $MNU "s.replace('side: BorderSide(color: p.outline),', 'side: BorderSide.none,')"

# --- steps --------------------------------------------------------------------
mutate $ST "confirm step taps cancel" $STEPS/interaction/i_confirm_the_dialog.dart "s.replace('mcConfirmButtonKey', 'mcCancelButtonKey')"
mutate $ST "cancel step taps confirm" $STEPS/interaction/i_cancel_the_dialog.dart "s.replace('mcCancelButtonKey', 'mcConfirmButtonKey')"
mutate $ST "confirm step does not settle" $STEPS/interaction/i_confirm_the_dialog.dart "s.replace('await mcSettle(tester);', '')"
mutate $ST "choose step matches a substring" $STEPS/interaction/i_choose_in_the_sheet.dart "s.replace('find.text(option)', 'find.textContaining(option)')"
mutate $ST "choose step looks in the wrong overlay" $STEPS/interaction/i_choose_in_the_sheet.dart "re.sub(r'find\\.byWidgetPredicate\\(\\(w\\) => w is McChoiceList\\)', 'find.byType(McDialog)', s)"
mutate $ST "choose step does not assert one match" $STEPS/interaction/i_choose_in_the_sheet.dart "s.replace('findsOneWidget,\n    reason: \'exactly one option', 'findsWidgets,\n    reason: \'exactly one option')"
mutate $ST "toast step matches a substring" $STEPS/assertions/the_toast_is_shown.dart "s.replace('find.text(text)', 'find.textContaining(text)')"

# --- the sign-in sheet --------------------------------------------------------
mutate $SI "sign-in sheet allows back while busy" $SIGN "s.replace('canPop: !_busy,', 'canPop: true,')"
mutate $SI "sign-in sheet allows a drag while busy" $SIGN "s.replace('onVerticalDragStart: _busy ? (_) {} : null,', 'onVerticalDragStart: null,')"
mutate $SI "sign-in sheet answers true on Not now" $SIGN "s.replace('Navigator.of(context).pop(false)', 'Navigator.of(context).pop(true)')"
mutate $SI "sign-in sheet keeps Not now enabled while busy" $SIGN "re.sub(r'onPressed: _busy\\s*\\? null\\s*: \\(\\) => Navigator', 'onPressed: () => Navigator', s)"

echo
echo "TALLY: killed=$killed survived=$survived broken=$broken not-applied=$notapplied total=$((killed+survived+broken+notapplied))"
exit $rc
