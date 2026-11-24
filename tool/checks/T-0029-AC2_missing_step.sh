#!/bin/bash
# T-0029-AC2: a missing (or shadowed) step fails the build naming it, and the
# build writes no file outside bazel-out (the stock bdd_widget_test Builder
# would have written step stubs into the source tree).
#   tool/checks/T-0029-AC2_missing_step.sh [--out FILE]
# MC_OUTPUT_BASE=<dir> runs Bazel with that --output_base.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BZ=("$BAZELW")
[[ -n "${MC_OUTPUT_BASE:-}" ]] && BZ+=("--output_base=$MC_OUTPUT_BASE")
rc=0
report "# T-0029-AC2: missing steps fail the build, nothing is written" ""

# Every file in the fixture package (tracked, untracked and ignored), plus
# git's view of the whole tree, before and after.
snapshot() {
  find spike/bdd_sample -type f | LC_ALL=C sort | xargs shasum 2>/dev/null
  git status --porcelain --ignored
}
before="$(snapshot)"
log="$(mktemp)"

run_case() {  # run_case <target> <expected text>...
  local target="$1"; shift
  "${BZ[@]}" build --noremote_accept_cached --disk_cache= "$target" > "$log" 2>&1
  local code=$?
  report "## \`$target\` (exit $code)" '```'
  report "$(plain "$log" | grep -A8 'BDD generation failed' | head -12)"
  report '```'
  if [[ $code == 0 ]]; then report "- FAIL: the build succeeded"; rc=1; fi
  for want in "$@"; do
    if plain "$log" | grep -qF -- "$want"; then
      report "- names \`$want\`"
    else
      report "- FAIL: output does not name \`$want\`"; rc=1
    fi
  done
}
run_case //spike/bdd_sample/test/negative:missing_step \
  "2 step(s) have no definition" \
  '"the moon is made of cheese" -> step/the_moon_is_made_of_cheese.dart' \
  '"I count {3} craters" -> step/i_count_craters.dart'
run_case //spike/bdd_sample/test/negative:shadowed_step \
  "step/i_see.dart shadows package:mc_test_steps/mc_test_steps.dart"

after="$(snapshot)"
if [[ "$before" == "$after" ]]; then
  report "" "- source tree unchanged (every file under spike/bdd_sample hashed, plus \`git status --ignored\`)"
else
  report "" "- FAIL: the source tree changed:" '```' "$(diff <(echo "$before") <(echo "$after"))" '```'
  rc=1
fi
rm -f "$log"
finish T-0029-AC2 $rc
