#!/bin/bash
# T-0037: every fix and every TL decision has a test that fails without it.
# Each mutation reverts one change in the working tree, runs the test targets,
# expects at least one to FAIL, and restores the file (also on error). Exit 1
# when a mutation survives, does not compile, or a restore fails.
#   MC_TASK=T-0037 MC_ROLE=engineer documents/evidence/T-0037/engineer/mutations.sh
# MC_TASK and MC_ROLE name the output base and the log (/tmp/mc-ob-<task>-<role>,
# /tmp/mc-<task>-<role>-mutations.log); both are required, so two agents never
# share a log. MC_OB and MC_LOG override the names.
# This script also carries T-0036's mutations, re-expressed for the T-0037
# widget (the T-0036 script's old texts no longer exist in the widget).
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO"
: "${MC_TASK:?set MC_TASK (e.g. T-0037)}" "${MC_ROLE:?set MC_ROLE (e.g. engineer)}"
OB="${MC_OB:-/tmp/mc-ob-$MC_TASK-$MC_ROLE}"
LOG="${MC_LOG:-/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log}"
rc=0
current=""
restore() { [ -n "$current" ] && [ -f "$current.mut-orig" ] && mv -f "$current.mut-orig" "$current"; current=""; }
trap restore EXIT

TARGETS=(//utility/mc_feature_flow:flow_kit_test //utility/mc_feature_flow:flow_back_button_test)

# mutate <name> <file> <old> <new> [<old2> <new2>]  (each old text must occur)
mutate() {
  local name=$1 file=$2
  shift 2
  cp "$file" "$file.mut-orig"
  current=$file
  if ! /usr/bin/python3 -I - "$file" "$@" <<'PY'
import sys
path, pairs = sys.argv[1], sys.argv[2:]
text = open(path).read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if old not in text:
        sys.exit("mutation text not found in " + path + ": " + old)
    text = text.replace(old, new, 1)
open(path, "w").write(text)
PY
  then
    echo "MUTATION $name: INVALID (text not found)"; rc=1; restore; return
  fi
  if tool/bazelw --output_base="$OB" test "${TARGETS[@]}" >"$LOG" 2>&1; then
    echo "MUTATION $name: SURVIVED (tests passed)"; rc=1
  elif grep -a -q 'Build did NOT complete' "$LOG"; then
    echo "MUTATION $name: COMPILE ERROR (not killed by a test)"; rc=1
  elif ! grep -a -q -E '^//.*FAILED' "$LOG"; then
    echo "MUTATION $name: ERROR (no failing test)"; rc=1
  else
    echo "MUTATION $name: killed by $(grep -a -E '^//.*FAILED' "$LOG" | sed 's/ .*//' | tr '\n' ' ')"
  fi
  restore
}

BTN=utility/mc_feature_flow/lib/src/flow_context.dart
FLOW=utility/mc_feature_flow/lib/src/feature_flow.dart
FB=third_party/flow_builder/lib/flow_builder.dart

# --- TL decision 1: the flow publishes its outer route state ----------------
mutate "D1: updateShouldNotify ignores outerCanPop" $BTN \
  "container != oldWidget.container || outerCanPop != oldWidget.outerCanPop;" \
  "container != oldWidget.container;"
mutate "D1: FeatureFlow reads the outer navigator without a dependency" $FLOW \
  "final route = ModalRoute.of(context);" \
  "final route = Navigator.maybeOf(context)?.canPop() ?? false;" \
  "outerCanPop: route != null && !route.isFirst," "outerCanPop: route,"
mutate "D1: the button never reads outerCanPop (root always shows back)" $BTN \
  "if (outer != null && scope.outerCanPop) {" "if (outer != null) {"
# --- TL decision 2: safe outside a flow --------------------------------------
mutate "D2: the scope lookup throws outside a flow" $BTN \
  "route.isFirst ? FlowScope.maybeOf(context) : null" \
  "route.isFirst ? FlowScope.of(context) : null"
mutate "D2: no DrawerButton outside a flow / off the root" $BTN \
  "    if (hasDrawer) {
      return const DrawerButton();
    }
    if (route.impliesAppBarDismissal" \
  "    if (route.impliesAppBarDismissal"
# --- TL decision 3: precedence on the flow root ------------------------------
mutate "D3: local history ignored on the flow root" $BTN \
  "if (route.willHandlePopInternally) {" \
  "if (route.willHandlePopInternally && scope.outerCanPop) {"
mutate "D3: a drawer beats a local history entry" $BTN \
  "if (route.willHandlePopInternally) {" \
  "if (route.willHandlePopInternally && !hasDrawer) {"
mutate "D3: no DrawerButton on the flow root" $BTN \
  "      if (hasDrawer) {
        return const DrawerButton();
      }
      final outer" \
  "      final outer"
mutate "D3: root back button pops instead of maybePop (R-1)" $BTN \
  "unawaited(outer.maybePop())" "outer.pop()"
# --- flow_builder (patch changes 4 and 5) ------------------------------------
mutate "flow_builder: PopScope not always mounted (R-3)" $FB \
  "return PopScope(canPop: !condition, child: child);" \
  "return condition ? PopScope(canPop: false, child: child) : child;"
mutate "flow_builder change 5: no recompute after a new state: from the parent" $FB \
  "_recomputeCanPopAfterFrame();
    } else if" "} else if"
mutate "flow_builder change 5: no recompute after a new controller: from the parent" $FB \
  "_recomputeCanPopAfterFrame();
    }
  }

  FlowController<T> _initController" "}
  }

  FlowController<T> _initController"
mutate "flow_builder change 4: no recompute after a controller update (T-0036)" $FB \
  "if (mounted) setState(() {});
    });" "if (mounted) {}
    });"
# --- T-0036's mutations, re-expressed ----------------------------------------
mutate "T-0036: isFirst ignored (every route is the flow root)" $BTN \
  "route.isFirst ? FlowScope.maybeOf(context) : null" \
  "FlowScope.maybeOf(context)"
mutate "T-0036: fullscreen dialog gets a BackButton" $BTN \
  "? const CloseButton()
          : const BackButton();" \
  "? const BackButton()
          : const BackButton();"

exit "$rc"
