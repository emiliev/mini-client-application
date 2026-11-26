#!/bin/bash
# T-0036-AC1 negative control: puts the old `context.flowLeading()` (T-0034)
# back, switches the AC1 test's and the AC2 root page's leading to it, and runs
# flow_kit_test. Expected: T-0036-AC1 FAILS (other widget tests may too: they
# use the new widget). Exit 0 when AC1 failed, 1 when it passed. Restores both files on exit.
#   MC_OB=/tmp/mc-ob-T-0036-engineer documents/evidence/T-0036/engineer/AC1_negative_control.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO"
OB="${MC_OB:-/tmp/mc-ob-T-0036-engineer}"
LOG="${MC_LOG:-/tmp/mc-T-0036-engineer-ac1.log}"
CTX=utility/mc_feature_flow/lib/src/flow_context.dart
TST=utility/mc_feature_flow/test/flow_kit_test.dart
cp "$CTX" "$CTX.mut-orig"; cp "$TST" "$TST.mut-orig"
trap 'mv -f "$CTX.mut-orig" "$CTX"; mv -f "$TST.mut-orig" "$TST"' EXIT
cat >> "$CTX" <<'DART'

extension McFlowNavigation on BuildContext {
  Widget? flowLeading() {
    final outer = FlowScope.read(this).outerNavigator;
    final inner = Navigator.maybeOf(this);
    if (outer == null || !outer.canPop() || (inner?.canPop() ?? false)) {
      return null;
    }
    return BackButton(onPressed: () => unawaited(outer.maybePop()));
  }
}
DART
/usr/bin/python3 -I - "$TST" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
assert s.count("leading: const McFlowBackButton()") >= 2
s = s.replace("leading: const McFlowBackButton()", "leading: context.flowLeading()")
open(p, "w").write(s)
PY
tool/bazelw --output_base="$OB" test //utility/mc_feature_flow:flow_kit_test --test_output=errors >"$LOG" 2>&1
grep -a -E "FAIL  T-0036-AC1|PASS  T-0036-AC1|Expected|Actual" "$LOG" | head -30
grep -a -q "FAIL  T-0036-AC1 the back button is present" "$LOG"
