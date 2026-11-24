#!/bin/bash
# T-0028-AC1: the injectable shim's .config.dart (and every non-empty shard)
# equals build_runner's with stock injectable_generator 3.1.3, byte for byte
# (tool/build_runner_overlay/injectable_reference.sh).
#   tool/checks/T-0028-AC1_injectable_matches_build_runner.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
log="$(mktemp)"
"$REPO/tool/build_runner_overlay/injectable_reference.sh" spike/di_sample > "$log" 2>&1; rc=$?
report "# T-0028-AC1: Bazel injectable codegen vs build_runner" "" '```' \
  "$(grep -a -E '^(==|   |EQUAL|EMPTY|DIFFER|MISSING|DRIFT|build_runner wrote)' "$log")" '```'
[[ $rc -eq 0 ]] || report "" "Full log:" '```' "$(tail -60 "$log")" '```'
rm -f "$log"
finish T-0028-AC1 $([[ $rc -eq 0 ]] && echo 0 || echo 1)
