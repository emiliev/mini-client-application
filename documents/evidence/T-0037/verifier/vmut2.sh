#!/bin/bash
# T-0037 Verifier's own mutations. Each mutates one file in the verifier
# worktree, runs the two mc_feature_flow test targets uncached, records the
# failing test names, and restores the file from a backup copy.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a23fd7f7ae6d56c1d
S=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0037-verifier
cd "$W" || exit 2
OB=/tmp/mc-ob-T-0037-verifier
LOG=$S/vmut2-current.log
OUT=$S/vmut2_results.log
: > "$OUT"
current=""
restore() { [ -n "$current" ] && [ -f "$S/bak" ] && cp -f "$S/bak" "$current"; current=""; }
trap restore EXIT
TARGETS=(//utility/mc_feature_flow:flow_kit_test //utility/mc_feature_flow:flow_back_button_test)
mutate() {
  local name=$1 file=$2; shift 2
  cp -f "$file" "$S/bak"
  current=$file
  if ! /usr/bin/python3 -I - "$file" "$@" <<'PY'
import sys
path, pairs = sys.argv[1], sys.argv[2:]
text = open(path).read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if text.count(old) != 1:
        sys.exit("not exactly once: " + old)
    text = text.replace(old, new, 1)
open(path, "w").write(text)
PY
  then echo "$name: INVALID" | tee -a "$OUT"; restore; return; fi
  tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all "${TARGETS[@]}" >"$LOG" 2>&1
  local rc=$?
  if grep -a -q -E 'Build did NOT complete|FAILED TO BUILD' "$LOG"; then echo "$name: COMPILE ERROR" | tee -a "$OUT"
  elif [ $rc -eq 0 ]; then echo "$name: SURVIVED" | tee -a "$OUT"
  else
    echo "$name: KILLED by" | tee -a "$OUT"
    tr '\r' '\n' < "$LOG" | grep -a -E '^  FAIL  ' | sort -u | sed 's/^/    /' | tee -a "$OUT"
  fi
  restore
}
BTN=utility/mc_feature_flow/lib/src/flow_context.dart
FLOW=utility/mc_feature_flow/lib/src/feature_flow.dart
FB=third_party/flow_builder/lib/flow_builder.dart
LH='      if (route.willHandlePopInternally && route.impliesAppBarDismissal) {
        return const BackButton();
      }
'
DR='      if (hasDrawer) {
        return const DrawerButton();
      }
'
OUTER='      final outer = scope.outerNavigator;
      if (outer != null && scope.outerCanPop) {
        return BackButton(onPressed: () => unawaited(outer.maybePop()));
      }
'
# Order: every permutation of the three steps except the real one.
mutate "V1 order: outer, local, drawer" $BTN "$LH$DR$OUTER" "$OUTER$LH$DR"
mutate "V2 order: local, outer, drawer" $BTN "$LH$DR$OUTER" "$LH$OUTER$DR"
mutate "V3 order: drawer, local, outer" $BTN "$LH$DR$OUTER" "$DR$LH$OUTER"
mutate "V4 order: drawer, outer, local" $BTN "$LH$DR$OUTER" "$DR$OUTER$LH"
mutate "V5 order: outer, drawer, local" $BTN "$LH$DR$OUTER" "$OUTER$DR$LH"
mutate "V6 local history step removed" $BTN "$LH" ""
mutate "V7 local history entry gets the outer button" $BTN \
  "        return const BackButton();
      }
      if (hasDrawer) {
        return const DrawerButton();
      }
      final outer" \
  "        return BackButton(onPressed: () => scope.outerNavigator?.maybePop());
      }
      if (hasDrawer) {
        return const DrawerButton();
      }
      final outer"
mutate "V8 maybePop -> pop" $BTN "unawaited(outer.maybePop())" "outer.pop()"
mutate "V9 outerCanPop from route?.canPop" $FLOW \
  "outerCanPop: route != null && !route.isFirst," "outerCanPop: route?.canPop ?? false,"
mutate "V10 outerCanPop from Navigator.of(context).canPop() (dependency kept)" $FLOW \
  "outerCanPop: route != null && !route.isFirst," \
  "outerCanPop: route != null && Navigator.of(context).canPop(),"
mutate "V11 FlowScope.maybeOf registers no dependency" $BTN \
  "      context.dependOnInheritedWidgetOfExactType<FlowScope>();
" "      context.getInheritedWidgetOfExactType<FlowScope>();
"
mutate "V13 PopScope conditionally mounted (stock)" $FB \
  "return PopScope(canPop: !condition, child: child);" \
  "return condition ? PopScope(canPop: false, child: child) : child;"
mutate "V14 patch change 5 reverted (both branches)" $FB \
  "        ..add(_state);
      _recomputeCanPopAfterFrame();
    } else if" "        ..add(_state);
    } else if" \
  "        ..add(_state);
      _recomputeCanPopAfterFrame();
    }
  }" "        ..add(_state);
    }
  }"
mutate "V15 outside a flow: drawer ignored on a first route" $BTN \
  "    if (hasDrawer) {
      return const DrawerButton();
    }
    if (route.impliesAppBarDismissal" \
  "    if (hasDrawer && !route.isFirst) {
      return const DrawerButton();
    }
    if (route.impliesAppBarDismissal"
mutate "V16 updateShouldNotify always false" $BTN \
  "container != oldWidget.container || outerCanPop != oldWidget.outerCanPop;" "false;"
mutate "V17 outerCanPop true whenever routed" $FLOW \
  "outerCanPop: route != null && !route.isFirst," "outerCanPop: route != null,"
mutate "V19 off-flow: canPop without impliesAppBarDismissal" $BTN \
  "if (route.impliesAppBarDismissal && route.canPop) {" "if (route.canPop) {"
mutate "W1 root: impliesAppBarDismissal clause dropped" $BTN \
  "if (route.willHandlePopInternally && route.impliesAppBarDismissal) {" \
  "if (route.willHandlePopInternally) {"
mutate "W2 root: drawer entry excluded by !hasDrawer instead" $BTN \
  "if (route.willHandlePopInternally && route.impliesAppBarDismissal) {" \
  "if (route.willHandlePopInternally && !hasDrawer) {"
mutate "W3 isFlowNavigator always true" $BTN \
  "return observer == null || identical(observer.navigator, navigator);" "return true;"
mutate "W4 observer not attached to the flow navigator" $FLOW \
  "              observers: [_navigatorObserver],
" ""
mutate "W5 FutureBuilder builder depends on the outer route (rebuild scope)" $FLOW \
  "        builder: (context, snapshot) {
          if (snapshot.hasError) {" \
  "        builder: (context, snapshot) {
          ModalRoute.of(context);
          if (snapshot.hasError) {"
mutate "W6 host builds a new FlowBuilder each time (child ignored)" $FLOW \
  "      flowNavigatorObserver: flowNavigatorObserver,
      child: child,
    );" \
  "      flowNavigatorObserver: flowNavigatorObserver,
      child: KeyedSubtree(key: ValueKey<Object?>(route?.isCurrent), child: child),
    );"
mutate "INFO W7 a scope without an observer says no (stricter fallback)" $BTN \
  "return observer == null || identical(observer.navigator, navigator);" \
  "return observer != null && identical(observer.navigator, navigator);"
echo DONE >> "$OUT"
