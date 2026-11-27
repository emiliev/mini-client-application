#!/bin/bash
# T-0059 mutation check: each mutant of mc_ds_charts (and of the palette roles
# in mc_ds_tokens) must make a test fail. A surviving mutant means a test does
# not prove its claim.
#   - REFUSES to run on a dirty tree (restoring a mutant is a `git checkout`).
#   - The restore trap is set before the first edit, and also covers INT/TERM.
#   - The unmutated tree must pass first (positive control).
#   - Outcome per mutant, from the Bazel output only:
#       KILLED    the output has "FAILED in" (a test target failed);
#       BROKEN    the output has "Build did NOT complete" (the mutant did not
#                 compile or analyse: it proves nothing, and is counted apart);
#       SURVIVED  every target PASSED.
#   - The tree is verified clean after each mutant.
#   MC_TASK=T-0059 MC_ROLE=engineer documents/evidence/T-0059/engineer/mutations.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TASK="${MC_TASK:-T-0059}"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OB:-/tmp/mc-ob-$TASK-$ROLE-mut}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bz() { tool/bazelw --output_base="$OB" "$@"; }
PKG=//utility/mc_ds_charts
PLAIN=("$PKG:geometry_test" "$PKG:painter_test" "$PKG:charts_test")
GOLDEN=("${PLAIN[@]}" "$PKG:golden_test")
SCOPE=(utility/mc_ds_charts/lib utility/mc_ds_tokens/lib)

if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the working tree is dirty (commit or discard first)"
  git status --short | head
  exit 2
fi

restore() { git checkout -- "${SCOPE[@]}" 2>/dev/null; }
trap restore EXIT INT TERM   # before the first edit

run() { bz test "$@" --nocache_test_results --test_output=errors 2>&1 | tr '\r' '\n'; }

base="$(run "${GOLDEN[@]}")"
if grep -q "Build did NOT complete" <<< "$base" || grep -q "FAILED in" <<< "$base" || ! grep -q "PASSED" <<< "$base"; then
  echo "BASELINE FAILS"; tail -20 <<< "$base"; exit 1
fi
echo "baseline (geometry, painter, charts, golden): PASS"

N="$(python3 -I "$HERE/mutants.py" count)"
killed=0; survived=0; broken=0; napplied=0
for ((i = 0; i < N; i++)); do
  info="$(python3 -I "$HERE/mutants.py" apply "$i")" || {
    echo "$info: NOT APPLIED"; napplied=$((napplied + 1)); restore; continue; }
  name="${info%%|*}"; rest="${info#*|}"; kind="${rest%%|*}"; file="${rest#*|}"
  # keep the mutated file formatted so only the test result decides
  fvm dart format "$file" > /dev/null 2>&1
  if [[ "$kind" == golden ]]; then out="$(run "${GOLDEN[@]}")"; else out="$(run "${PLAIN[@]}")"; fi
  if grep -q "Build did NOT complete" <<< "$out"; then
    echo "[$((i + 1))/$N] $name: BROKEN (did not build; proves nothing)"; broken=$((broken + 1))
  elif grep -q "FAILED in" <<< "$out"; then
    echo "[$((i + 1))/$N] $name: KILLED ($(grep -a -m1 -E '^//.*FAILED' <<< "$out" | sed -E 's/ +FAILED.*//; s#//utility/mc_ds_charts:##'))"; killed=$((killed + 1))
  else
    echo "[$((i + 1))/$N] $name: SURVIVED"; survived=$((survived + 1))
  fi
  restore
  [[ -z "$(git status --porcelain)" ]] || { echo "RESTORE FAILED"; git status --short; exit 1; }
done
echo
echo "mutants: $N, killed: $killed, survived: $survived, broken: $broken, not applied: $napplied"
[[ $survived -eq 0 && $broken -eq 0 && $napplied -eq 0 ]]
