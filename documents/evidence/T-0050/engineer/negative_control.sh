#!/bin/bash
# T-0050 review round, item 5: negative control for the step
# `{user} signs in just before the app sends {route}`. A route that no request
# matches must turn the race scenario RED, in two variants:
#   A. the scenario keeps its `the session belongs to` assertion: it fails;
#   B. that assertion is removed too, so nothing else can catch it: the step's
#      own teardown check fails ("never signed in").
# The scenario file is restored with `git checkout`.
#   MC_TASK=T-0050 MC_ROLE=engineer documents/evidence/T-0050/engineer/negative_control.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?}" "${MC_ROLE:?}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
F=feature/comics/comics_details/test/feature/comics_details_favourite.feature
OUT="documents/evidence/$MC_TASK/$MC_ROLE/negative_control.log"
if ! git diff --quiet -- "$F"; then echo "REFUSING: $F has uncommitted edits"; exit 2; fi
trap 'git checkout -- "$F"' EXIT

MUTATE='
import sys
p, drop = sys.argv[1], sys.argv[2] == "1"
s = open(p).read()
t = s.replace("signs in just before the app sends {'"'"'PUT /v1/me/favourites/comic/501500'"'"'}",
              "signs in just before the app sends {'"'"'PUT /v1/me/favourites/comic/999999'"'"'}", 1)
if drop:
    # No tap either: nothing but the teardown check of the step can fail.
    lines = [l for l in t.split("\n") if "the session belongs to" not in l]
    i = next(k for k, l in enumerate(lines) if "999999" in l)
    assert "I tap" in lines[i + 1]
    del lines[i + 1]
    t = "\n".join(lines)
assert t != s
open(p, "w").write(t)
'

LAST=""
run_variant() {  # run_variant <name> <drop session-belongs lines: 0|1>
  git checkout -- "$F"
  /usr/bin/python3 -I -c "$MUTATE" "$F" "$2" || { echo "MUTATION NOT APPLIED"; exit 3; }
  LAST="$(tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all //feature/comics/comics_details:bdd_test 2>&1 | tr '\r' '\n')"
  echo "## variant $1"
  grep -a -E "^  FAIL  .*wrong user|never signed in" <<< "$LAST" | head -4
}

rc=0
{
  echo "# negative control: the step points at a route no request matches"
  run_variant "A: wrong route, 'session belongs' kept" 0
  grep -a -q "^  FAIL  .*sends nothing for the wrong user" <<< "$LAST" || { echo "VARIANT A DID NOT GO RED"; rc=1; }
  run_variant "B: wrong route, no tap, 'session belongs' removed (only the teardown check can fail)" 1
  if ! { grep -a -q "never signed in" <<< "$LAST"; }; then
    echo "VARIANT B DID NOT GO RED FOR THE RIGHT REASON"; rc=1
  fi
  if [[ $rc == 0 ]]; then echo "NEGATIVE CONTROL OK: both variants went red"; else echo "NEGATIVE CONTROL FAILED"; fi
} 2>&1 | tee "$OUT"
grep -q "NEGATIVE CONTROL OK" "$OUT"
