#!/bin/bash
# T-0050 review round, item 5: negative control for the step
# `{user} signs in just before the app sends {route}`. A route that no request
# matches must turn the race scenario RED (the step fails at teardown because
# the hook never fired). The scenario file is restored with `git checkout`.
#   MC_TASK=T-0050 MC_ROLE=engineer documents/evidence/T-0050/engineer/negative_control.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?}" "${MC_ROLE:?}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
F=feature/comics/comics_details/test/feature/comics_details_favourite.feature
OUT="documents/evidence/$MC_TASK/$MC_ROLE/negative_control.log"
if ! git diff --quiet -- "$F"; then echo "REFUSING: $F has uncommitted edits"; exit 2; fi
trap 'git checkout -- "$F"' EXIT
/usr/bin/python3 -I - "$F" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
t = s.replace("signs in just before the app sends {'PUT /v1/me/favourites/comic/501500'}",
              "signs in just before the app sends {'PUT /v1/me/favourites/comic/999999'}", 1)
assert t != s
open(p, "w").write(t)
EOF
out="$(tool/bazelw --output_base="$OB" test --nocache_test_results --test_output=all //feature/comics/comics_details:bdd_test 2>&1 | tr '\r' '\n')"
{
  echo "# negative control: the step points at a route no request matches"
  grep -a -E "^  FAIL  |never signed in|race was not exercised|^//feature" <<< "$out"
} | tee "$OUT"
if grep -a -q "^  FAIL  .*sends nothing for the wrong user" <<< "$out" && grep -a -q "never signed in" <<< "$out"; then
  echo "NEGATIVE CONTROL OK: the scenario went red" | tee -a "$OUT"
else
  echo "NEGATIVE CONTROL FAILED: the scenario did not go red" | tee -a "$OUT"; exit 1
fi
