#!/bin/bash
# T-0029-AC1: a scenario tagged @T-0001-AC1 runs under :bdd_test with the AC
# ID in its JUnit case name (moved there by mcTestWidgets, plan 05 KD4). Also
# copies the generated sources and test.xml into the evidence dir.
#   tool/checks/T-0029-AC1_junit_names.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BZ=("$BAZELW")
[[ -n "${MC_OUTPUT_BASE:-}" ]] && BZ+=("--output_base=$MC_OUTPUT_BASE")
rc=0
target=//spike/bdd_sample:bdd_test
report "# T-0029-AC1: AC tags reach the JUnit case names" ""
log="$(mktemp)"
# --nocache_test_results: the test must really run, not replay a cached pass.
"${BZ[@]}" test --nocache_test_results "$target" > "$log" 2>&1
code=$?
report "\`tool/bazelw test --nocache_test_results $target\`: exit $code" '```' \
  "$(plain "$log" | grep -E '^//|Executed')" '```'
[[ $code == 0 ]] || rc=1
xml="$("${BZ[@]}" info bazel-testlogs 2>/dev/null)/spike/bdd_sample/bdd_test/test.xml"
bin="$("${BZ[@]}" info bazel-bin 2>/dev/null)/spike/bdd_sample/test/feature"
report "## JUnit case names (\`$target\` test.xml)" '```'
report "$(grep -o '<testcase name="[^"]*"' "$xml" | sed 's/<testcase name=//')"
report '```'
for want in '\[T-0001-AC1\]' '\[T-0029-AC1\]' '\[T-0029-AC4\]'; do
  if grep -qE "<testcase name=\"[^\"]*$want\"" "$xml"; then
    report "- a case name ends with ${want//\\/}"
  else
    report "- FAIL: no case name with ${want//\\/}"; rc=1
  fi
done
grep -q 'failures="0" errors="0" skipped="0"' "$xml" || { report "- FAIL: failures or skips in test.xml"; rc=1; }
if [[ -n "$OUT" ]]; then
  ev="$(dirname "$OUT")"
  mkdir -p "$ev/generated"
  cp "$xml" "$ev/T-0029-AC1_bdd_test.xml"
  cp "$bin"/*.dart "$ev/generated/"
  report "" "Saved: \`T-0029-AC1_bdd_test.xml\` and \`generated/*.dart\` (the bazel-bin outputs)."
fi
rm -f "$log"
finish T-0029-AC1 $rc
