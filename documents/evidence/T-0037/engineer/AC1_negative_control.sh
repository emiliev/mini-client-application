#!/bin/bash
# T-0037-AC1 negative control: puts T-0036's widget and flow back (flow_context.dart
# and feature_flow.dart as at b8f152c, the T-0036 merge), runs
# flow_back_button_test and expects both T-0037-AC1 tests that start from a
# stack change to FAIL (the removeRoute one too). Restores both files on exit.
# Exit 0 when every T-0037-AC1 test failed, 1 otherwise.
#   MC_OB=/tmp/mc-ob-T-0037-engineer documents/evidence/T-0037/engineer/AC1_negative_control.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO"
OB="${MC_OB:-/tmp/mc-ob-T-0037-engineer}"
LOG="${MC_LOG:-/tmp/mc-T-0037-engineer-ac1.log}"
BASE="${MC_BASE:-b8f152c}"
CTX=utility/mc_feature_flow/lib/src/flow_context.dart
FLW=utility/mc_feature_flow/lib/src/feature_flow.dart
cp "$CTX" "$CTX.mut-orig"; cp "$FLW" "$FLW.mut-orig"
trap 'mv -f "$CTX.mut-orig" "$CTX"; mv -f "$FLW.mut-orig" "$FLW"' EXIT
git show "$BASE:$CTX" > "$CTX" && git show "$BASE:$FLW" > "$FLW" || exit 2
tool/bazelw --output_base="$OB" test //utility/mc_feature_flow:flow_back_button_test --test_output=errors >"$LOG" 2>&1
grep -a -E "^  (PASS|FAIL)  T-0037-AC1" "$LOG"
passes=$(grep -a -c -E "^  PASS  T-0037-AC1" "$LOG")
fails=$(grep -a -c -E "^  FAIL  T-0037-AC1" "$LOG")
echo "T-0037-AC1 on $BASE's widget: $fails failed, $passes passed"
[[ "$fails" -ge 1 && "$passes" -eq 0 ]]
