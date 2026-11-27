#!/bin/bash
# T-0058 flake check (protocol DoD): every new target that animates or uses
# timers passes 50 runs, uncached, with 0 failures. Writes the log next to
# this script as flake-50.log.
#   MC_TASK=T-0058 MC_ROLE=engineer documents/evidence/T-0058/engineer/flake-50.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
OB="/tmp/mc-ob-${MC_TASK:-T-0058}-${MC_ROLE:-engineer}"
LOG="$(dirname "${BASH_SOURCE[0]}")/flake-50.log"
tmp="$(mktemp)"
tool/bazelw --output_base="$OB" test \
  //utility/mc_ds_overlays:overlays_test //utility/mc_ds_overlays:golden_test \
  //utility/mc_test_steps:overlay_steps_test //app/wiring/app_core:sign_in_sheet_test \
  --runs_per_test=50 --nocache_test_results --test_output=errors > "$tmp" 2>&1
rc=$?
{
  echo "# T-0058 flake check: --runs_per_test=50 --nocache_test_results"
  echo "# targets: overlays_test, golden_test, overlay_steps_test, sign_in_sheet_test"
  tr '\r' '\n' < "$tmp" | grep -E "PASSED|FAILED|FLAKY|Stats over|Executed|ERROR"
  echo "# exit code: $rc"
} > "$LOG"
rm -f "$tmp"
cat "$LOG"
exit $rc
