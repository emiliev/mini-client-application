#!/bin/bash
# T-0042-AC4: tool/ide_sync is safe.
#   1. `git status --porcelain` is the same before and after a sync (every
#      synced file is ignored).
#   2. No synced output is tracked, and no BUILD target takes one as a source
#      file (bazel query over kind("source file", deps(//...))).
#   3. Bazel builds and tests are byte-identical with and without a sync:
#        A. clean tree: build //... and test //..., hash every output file;
#        B. synced tree: build //... and test //... again. B runs no action and
#           no test (all cached, so the action and test keys are unchanged),
#           and every output hashes the same as in A.
# Negative controls (each must make its own step FAIL):
#   - an un-ignored stray file changes `git status`;
#   - `git add -f` of a synced file is reported as tracked;
#   - a planted `.g.dart` in a package without the glob exclusion shows up as a
#     source file, and a build with it runs actions.
#   tool/checks/T-0042-AC4_safety.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds the Bazel startup options (e.g. --output_base=...);
# MC_OUTPUT_BASE is passed on to tool/ide_sync.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
SYNC="$REPO/tool/ide_sync"
PLANT=utility/mc_prelude/lib/src/t0042_planted.g.dart
STRAY=utility/mc_prelude/lib/src/t0042_stray.dart
MAN=.dart_tool/mc_ide_sync.manifest
work="$(mktemp -d)"
rc=0
rows=()
cleanup() {
  rm -f "$REPO/$PLANT" "$REPO/$STRAY"
  [[ -z "${TRACKED_PROBE:-}" ]] || git reset -q -- "$TRACKED_PROBE" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT
row() { rows+=("| $1 | $2 | $3 |"); }
fail() { rc=1; row "$1" "**FAIL**" "$2"; }
pass() { row "$1" PASS "$2"; }
executed() {  # executed <build log>: true when the log shows a non-cached action
  plain "$1" | grep -a 'INFO: .* process' | grep -aEq 'sandbox|worker|[^-]local|remote'
}
hash_outputs() {  # every file under bazel-bin, hashed, sorted by path
  (cd "$REPO" && find -L bazel-bin -type f -print0 2>/dev/null | xargs -0 shasum -a 256 | sed 's/  /\t/' | awk -F'\t' '{print $2 "\t" $1}' | sort)
}
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "refusing: tracked files are modified" >&2; exit 2; }

report "# T-0042-AC4: tool/ide_sync is safe" ""

# --- A: no sync ---------------------------------------------------------------
"$SYNC" --clean >/dev/null
status0="$(git status --porcelain)"
bzw build //... >"$work/A_build.log" 2>&1 || { report '```' "$(plain "$work/A_build.log" | tail -15)" '```'; finish T-0042-AC4 1; }
bzw test //... >"$work/A_test.log" 2>&1
a_test_rc=$?
hash_outputs >"$work/A.hashes"
a_n=$(wc -l <"$work/A.hashes" | tr -d ' ')
[[ $a_test_rc == 0 ]] && pass "A. no sync: build and test //..." "test passed; $a_n output files hashed" || fail "A. no sync: build and test //..." "test //... exit $a_test_rc"

# --- sync ---------------------------------------------------------------------
if ! "$SYNC" --env dev >"$work/sync.log" 2>&1; then report '```' "$(tail -15 "$work/sync.log")" '```'; finish T-0042-AC4 1; fi
nsync=$(wc -l <"$MAN" | tr -d ' ')

# 1. git status
status1="$(git status --porcelain)"
if [[ "$status0" == "$status1" ]]; then pass "1. git status after a sync" "unchanged ($nsync files synced, all ignored)"
else fail "1. git status after a sync" "$(diff <(echo "$status0") <(echo "$status1") | head -5)"; fi
printf '// stray, not ignored\n' >"$REPO/$STRAY"
if [[ "$(git status --porcelain)" == "$status1" ]]; then fail "1. negative control (stray file)" "git status did not change"
else pass "1. negative control (stray file)" "git status changed as it must"; fi
rm -f "$REPO/$STRAY"

# 2a. tracked
tracked=""
while IFS= read -r f; do [[ -z "$(git ls-files -- "$f")" ]] || tracked="$tracked $f"; done <"$MAN"
if [[ -z "$tracked" ]]; then pass "2a. no synced file is tracked" "$nsync checked"; else fail "2a. no synced file is tracked" "tracked:$tracked"; fi
TRACKED_PROBE="$(sed -n 2p "$MAN")"
git add -f -- "$TRACKED_PROBE"
probe_tracked=""
while IFS= read -r f; do [[ -z "$(git ls-files -- "$f")" ]] || probe_tracked="$probe_tracked $f"; done <"$MAN"
git reset -q -- "$TRACKED_PROBE"; TRACKED_PROBE=""
if [[ -n "$probe_tracked" ]]; then pass "2a. negative control (git add -f)" "reported:$probe_tracked"
else fail "2a. negative control (git add -f)" "a force-added synced file was not reported"; fi

# 2b. globs
sources_in_bazel() {  # synced paths that some target takes as a source file
  bzw query 'kind("source file", deps(//...))' --output=label 2>/dev/null |
    sed -n 's|^//\([^:]*\):\(.*\)$|\1/\2|p' | sort -u | comm -12 - <(sort "$MAN")
}
picked="$(sources_in_bazel)"
if [[ -z "$picked" ]]; then pass "2b. no BUILD glob picks up a synced file" "$nsync synced files, none is a source file of any target"
else fail "2b. no BUILD glob picks up a synced file" "$picked"; fi
printf '// planted: git-ignored, like a synced file\n' >"$REPO/$PLANT"
git check-ignore -q "$PLANT" || { report "the planted file is not git-ignored: the control is invalid"; finish T-0042-AC4 1; }
printf '%s\n' "$PLANT" >>"$MAN"
planted_seen="$(sources_in_bazel | grep -cx "$PLANT")"
sed -i '' "\|^$PLANT\$|d" "$MAN"
rm -f "$REPO/$PLANT"
if [[ "$planted_seen" -ge 1 ]]; then pass "2b. negative control (planted .g.dart in a package without the exclusion)" "the query reports it"
else fail "2b. negative control (planted .g.dart)" "the query did not report it"; fi

# --- B: synced ----------------------------------------------------------------
bzw build //... >"$work/B_build.log" 2>&1
b_build_rc=$?
bzw test //... >"$work/B_test.log" 2>&1
b_test_rc=$?
hash_outputs >"$work/B.hashes"
if [[ $b_build_rc == 0 && $b_test_rc == 0 ]]; then pass "B. synced: build and test //..." "both pass"
else fail "B. synced: build and test //..." "build exit $b_build_rc, test exit $b_test_rc"; fi
if executed "$work/B_build.log" || executed "$work/B_test.log"; then
  fail "3. synced tree runs no action and no test" "$(plain "$work/B_build.log" | grep -a 'INFO: .* process'; plain "$work/B_test.log" | grep -a 'INFO: .* process\|^Executed')"
else pass "3. synced tree runs no action and no test" "$(plain "$work/B_test.log" | grep -a '^Executed' | tail -1)"; fi
if cmp -s "$work/A.hashes" "$work/B.hashes"; then pass "3. outputs identical with and without a sync" "$a_n files, same bytes"
else fail "3. outputs identical with and without a sync" "$(diff "$work/A.hashes" "$work/B.hashes" | head -6)"; fi

# After B is hashed (this build adds its own outputs to bazel-bin): a build with
# a planted file in a package without the exclusion runs actions.
# Unique content, so an earlier run's cached action cannot hide the effect.
printf '// planted: git-ignored, like a synced file (%s)\n' "$$-$(date +%s)" >"$REPO/$PLANT"
bzw build //utility/mc_prelude/... >"$work/plant_build.log" 2>&1
if executed "$work/plant_build.log"; then pass "3. negative control (planted file in a build)" "the build ran actions, so 'no action' is a real signal"
else fail "3. negative control (planted file in a build)" "the build with the planted file ran nothing: the byte-identity check cannot fail"; fi
rm -f "$REPO/$PLANT"
bzw build //utility/mc_prelude/... >/dev/null 2>&1

report "| Check | Result | Detail |" "|---|---|---|" "${rows[@]}" "" \
  "Test summary (synced tree): $(plain "$work/B_test.log" | grep -a 'tests pass\|Executed' | tail -2 | paste -sd' ' -)"
finish T-0042-AC4 $rc
