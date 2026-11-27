#!/bin/bash
# T-0053 negative control for the e2e screens journey: with the router's
# analytics observer removed (mutation W02), `integration_test/
# analytics_screens_test.dart` must FAIL on the simulator. A pass here would
# mean the e2e proves nothing. Refuses a dirty tree, restores the file on any
# exit, and uses its own simulator (deleted by tool/e2e_ios.sh).
#
#   MC_TASK=T-0053 MC_ROLE=engineer documents/evidence/T-0053/engineer/e2e_negative_control.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK}"
: "${MC_ROLE:?set MC_ROLE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="/tmp/mc-$MC_TASK-$MC_ROLE-e2e-neg"
EVIDENCE="$HERE/e2e_negative_control"
FILE=app/mini_client/lib/src/router/app_router.dart
if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the working tree is not clean"; git status --porcelain; exit 2
fi
restore() { git checkout -- "$FILE"; }
trap restore EXIT INT TERM
/usr/bin/python3 -I "$HERE/mutation_specs.py" apply W02 || exit 1
git diff --stat -- "$FILE"
rm -rf "$OUT"
MC_OUTPUT_BASE="/tmp/mc-ob-$MC_TASK-$MC_ROLE" tool/e2e/prepare_pub_project.sh --app app/mini_client --out "$OUT" | tail -2
tool/e2e_ios.sh --task "$MC_TASK" --role "$MC_ROLE" --project "$OUT/app/mini_client" \
  --target integration_test/analytics_screens_test.dart --evidence-dir "$EVIDENCE"
rc=$?
restore
if [[ "$rc" == 1 ]]; then
  echo "NEGATIVE CONTROL OK: the e2e failed without the observer (exit 1)"; exit 0
fi
echo "NEGATIVE CONTROL FAILED: expected e2e exit 1, got $rc"; exit 1
