#!/bin/bash
# T-0053 mutation check. Each mutation (mutation_specs.py) must make a named
# test target FAIL with a failing test:
#   - KILLED   : Bazel reports `FAILED in` for a test target;
#   - BROKEN   : `Build did NOT complete` (a compile or analysis error), or a
#                timeout, or no test result at all. Not evidence: counted
#                separately and makes the script fail;
#   - SURVIVED : every target passed. Makes the script fail.
# The unmutated tree must pass first (baseline). The script REFUSES to run on a
# dirty tree (anything uncommitted, tracked or not), sets its restore trap
# BEFORE the first edit, and verifies at the end that every file it touches is restored.
#
#   MC_TASK=T-0053 MC_ROLE=engineer documents/evidence/T-0053/engineer/mutations.sh
#   MC_ONLY="G01 V03" ...   only the named mutations (after the baseline)
#   MC_DRY=1 ...            only check that every mutation applies, then restore
#
# Exit 0 only if every mutation was applied and killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK}"
: "${MC_ROLE:?set MC_ROLE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECS="$HERE/mutation_specs.py"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log"
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }
specs() { /usr/bin/python3 -I "$SPECS" "$@"; }

if [[ -n "$(git status --porcelain)" ]]; then
  say "REFUSING TO RUN: the working tree is not clean (commit or remove these first):"
  git status --porcelain | tee -a "$LOG"
  exit 2
fi

FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(specs files)
restore_all() { git checkout -- "${FILES[@]}"; }
# Set before any edit, so an interrupted run never leaves a mutation behind.
trap restore_all EXIT INT TERM

run() { bz test --nocache_test_results --test_output=errors "$@" 2>&1 | tr '\r' '\n'; }

if [[ -z "${MC_DRY:-}" ]]; then
  base="$(run //utility/mc_analytics/... //utility/mc_config/... //utility/mc_test_steps:analytics_steps_test //app/mini_client:analytics_screens_test //app/mini_client:bdd_test)"
  if grep -q "Build did NOT complete" <<< "$base" || grep -q -E "FAILED in|NO STATUS|TIMEOUT in" <<< "$base"; then
    say "BASELINE FAILS"; grep -E "FAILED|^ERROR|NO STATUS|did NOT" <<< "$base" | tee -a "$LOG"; exit 1
  fi
  say "baseline: PASS"
fi

n=0; killed=0; survived=0; broken=0; notapplied=0
for id in $(specs list); do
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then continue; fi
  n=$((n + 1))
  what="$(specs what "$id")"
  if ! msg="$(specs apply "$id")"; then
    say "$id: NOT APPLIED ($msg) -- $what"; notapplied=$((notapplied + 1)); restore_all; continue
  fi
  if [[ -n "${MC_DRY:-}" ]]; then
    say "$id: applies -- $what"; restore_all; continue
  fi
  # The build checks formatting of lib/ (F-0051): a mutant must be formatted,
  # or it is "broken" instead of killed. JSON files are not Dart.
  case "$(specs file "$id")" in *.dart) fvm dart format "$(specs file "$id")" > /dev/null ;; esac
  # shellcheck disable=SC2046
  out="$(run $(specs targets "$id"))"
  if grep -q "Build did NOT complete" <<< "$out"; then
    say "$id: BROKEN (build did not complete) -- $what"; broken=$((broken + 1))
  elif grep -q "TIMEOUT in" <<< "$out"; then
    say "$id: BROKEN (timeout) -- $what"; broken=$((broken + 1))
  elif grep -q "FAILED in" <<< "$out"; then
    failed="$(grep -a "FAILED in" <<< "$out" | sed -E 's/ +FAILED in.*//; s|^//||' | tr '\n' ' ')"
    say "$id: KILLED by ${failed}-- $what"; killed=$((killed + 1))
  elif grep -q "PASSED" <<< "$out"; then
    say "$id: SURVIVED -- $what"; survived=$((survived + 1))
  else
    say "$id: BROKEN (no test result) -- $what"; broken=$((broken + 1))
  fi
  restore_all
  # Only the files a mutation can touch: the notes of the run are not.
  if [[ -n "$(git status --porcelain -- "${FILES[@]}")" ]]; then say "RESTORE FAILED after $id"; git status --porcelain -- "${FILES[@]}" | tee -a "$LOG"; exit 1; fi
done

if [[ -z "$(git status --porcelain -- "${FILES[@]}")" ]]; then clean="clean"; else clean="DIRTY"; fi
say "---"
say "mutations: $n, killed: $killed, survived: $survived, broken: $broken, not applied: $notapplied; tree: $clean"
[[ "$survived" == 0 && "$broken" == 0 && "$notapplied" == 0 && "$clean" == "clean" ]]
