#!/bin/bash
# Verifier's own negative control for the committed T-0037 tests: keep the
# T-0037 FlowScope and FeatureFlow, but put T-0036's button body back
# (`outer.canPop()` read with no dependency, FlowScope.read on any first route,
# drawer only after the outer button). Runs flow_back_button_test uncached,
# lists PASS/FAIL per test, restores.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a23fd7f7ae6d56c1d
S=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0037-verifier
cd "$W" || exit 2
F=utility/mc_feature_flow/lib/src/flow_context.dart
cp -f "$F" "$S/ctx.bak"
trap 'cp -f "$S/ctx.bak" "$F"' EXIT
/usr/bin/python3 -I - "$F" <<'PY' || exit 2
import sys
p = sys.argv[1]; t = open(p).read()
old = t[t.index("    final scope = route.isFirst ? FlowScope.maybeOf(context) : null;"):t.index("    if (hasDrawer) {\n      return const DrawerButton();\n    }\n    if (route.impliesAppBarDismissal")]
new = """    if (route.isFirst) {
      final outer = FlowScope.read(context).outerNavigator;
      if (outer != null && outer.canPop()) {
        return BackButton(onPressed: () => unawaited(outer.maybePop()));
      }
      return hasDrawer ? const DrawerButton() : const SizedBox.shrink();
    }
"""
open(p, "w").write(t.replace(old, new, 1))
PY
sed -n '/Widget build(BuildContext context) {/,/^}/p' "$F" | head -30
tool/bazelw --output_base=/tmp/mc-ob-T-0037-verifier test --nocache_test_results --test_output=all \
  //utility/mc_feature_flow:flow_back_button_test > "$S/own_neg.raw.log" 2>&1
echo "bazel rc=$?"
tr '\r' '\n' < "$S/own_neg.raw.log" | grep -a -E '^  (PASS|FAIL)  ' | sort -u
