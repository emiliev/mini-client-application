#!/bin/bash
# T-0036 Verifier: install the probes, run them against the branch (new) or with
# origin/main's flowLeading code (old), then restore the tree.
#   run_probes.sh new|old
set -uo pipefail
MODE="$1"
S="$(cd "$(dirname "$0")" && pwd)"
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a9c18a5ca6a657e99
cd "$W" || exit 2
FF=utility/mc_feature_flow
CL=feature/characters/characters_list
restore() {
  git -C "$W" checkout -- "$FF" "$CL"
  rm -f "$FF/test/verifier_probe_test.dart" "$CL/test/verifier_probe_test.dart"
}
trap restore EXIT
cat "$S/ff_build_append.txt" >> "$FF/BUILD.bazel"
cat "$S/cl_build_append.txt" >> "$CL/BUILD.bazel"
cp "$S/characters_probe_test.dart.txt" "$CL/test/verifier_probe_test.dart"
if [[ "$MODE" == old ]]; then
  git -C "$W" show origin/main:$FF/lib/src/flow_context.dart > "$FF/lib/src/flow_context.dart"
  git -C "$W" show origin/main:$CL/lib/src/presentation/page/characters_list_page.dart \
    > "$CL/lib/src/presentation/page/characters_list_page.dart"
  sed -e 's/LEADING_EXPR/context.flowLeading()/' -e 's/const McFlowBackButton()/null/' "$S/verifier_probe_test.dart.txt" > "$FF/test/verifier_probe_test.dart"
else
  sed 's/LEADING_EXPR/const McFlowBackButton()/' "$S/verifier_probe_test.dart.txt" > "$FF/test/verifier_probe_test.dart"
fi
tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier test --nocache_test_results --test_output=all \
  //$FF:verifier_probe_test //$CL:verifier_probe_test > "$S/probes_$MODE.raw.log" 2>&1
echo "bazel rc=$?"
tr '\r' '\n' < "$S/probes_$MODE.raw.log" \
  | grep -a -E "^(V[0-9]|P[0-9])|  (PASS|FAIL) |Expected:|Actual:|Which:|PASSED|FAILED|Executed|rror:" \
  | grep -av '^\['
