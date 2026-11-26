#!/bin/bash
# T-0036: every fix has a test that fails without it. Each mutation
# reverts one fix in the working tree, runs the named test target, expects it
# to FAIL, and restores the file (also on error). Exit 1 when any mutation
# survives (its test still passed) or a restore fails.
#   MC_TASK=T-0036 MC_ROLE=engineer documents/evidence/T-0036/engineer/mutations.sh
# MC_TASK and MC_ROLE name the output base and the log (/tmp/mc-ob-<task>-<role>,
# /tmp/mc-<task>-<role>-mutations.log); both are required, so two agents never
# share a log. MC_OB and MC_LOG override the names.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO"
: "${MC_TASK:?set MC_TASK (e.g. T-0036)}" "${MC_ROLE:?set MC_ROLE (e.g. engineer)}"
OB="${MC_OB:-/tmp/mc-ob-$MC_TASK-$MC_ROLE}"
LOG="${MC_LOG:-/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log}"
rc=0
current=""
restore() { [ -n "$current" ] && [ -f "$current.mut-orig" ] && mv -f "$current.mut-orig" "$current"; current=""; }
trap restore EXIT

# mutate <name> <file> <python-old> <python-new> <target...>
mutate() {
  local name=$1 file=$2 old=$3 new=$4
  shift 4
  cp "$file" "$file.mut-orig"
  current=$file
  if ! /usr/bin/python3 -I - "$file" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
if old not in text:
    sys.exit("mutation text not found in " + path)
open(path, "w").write(text.replace(old, new, 1))
PY
  then
    echo "MUTATION $name: INVALID (text not found)"; rc=1; restore; return
  fi
  if tool/bazelw --output_base="$OB" test "$@" >"$LOG" 2>&1; then
    echo "MUTATION $name: SURVIVED (tests passed)  [$*]"; rc=1
  elif grep -a -q 'Build did NOT complete' "$LOG"; then
    echo "MUTATION $name: COMPILE ERROR (not killed by a test)  [$*]"; rc=1
  elif ! grep -a -q -E '^//.*FAILED' "$LOG"; then
    echo "MUTATION $name: ERROR (no failing test)  [$*]"; rc=1
  else
    echo "MUTATION $name: killed by $(grep -a -E '^//.*FAILED' "$LOG" | sed 's/ .*//' | tr '\n' ' ')"
  fi
  restore
}

FLOW=utility/mc_feature_flow/lib/src/flow_context.dart
T=//utility/mc_feature_flow:flow_kit_test

mutate "widget: isFirst ignored (every route is the flow root)" $FLOW \
  "if (route.isFirst) {" "if (route.isActive) {" $T

mutate "widget: root ignores whether the outer navigator can pop" $FLOW \
  "if (outer != null && outer.canPop()) {" "if (outer != null) {" $T

mutate "widget: no DrawerButton off the root" $FLOW \
  "    if (hasDrawer) {
      return const DrawerButton();
    }
    if (route.impliesAppBarDismissal" \
  "    if (route.impliesAppBarDismissal" $T

mutate "widget: fullscreen dialog gets a BackButton" $FLOW \
  "? const CloseButton()
          : const BackButton();" \
  "? const BackButton()
          : const BackButton();" $T

mutate "flow_builder hunk 4: no canPop recompute after a state update" \
  third_party/flow_builder/lib/flow_builder.dart \
  "if (mounted) setState(() {});
    });" "if (mounted) {}
    });" $T

exit "$rc"
