#!/bin/bash
# T-0031-AC6: McMediaScope moved to mc_ds_media and mc_media is pure Dart with
# one barrel. Re-runs the T-0030 closure check (mc_paging and mc_media have no
# Flutter in their closures; the positive control is now mc_ds_media), then
# checks the file layout and that nothing still imports the old barrel.
#   MC_OUTPUT_BASE=/tmp/mc-ob-x tool/checks/T-0031-AC6_closure.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
rc=0
report "# T-0031-AC6: McMediaScope moved, mc_media pure" ""

log="$(mktemp)"
if MC_OUTPUT_BASE="${MC_OUTPUT_BASE:-}" "$REPO/tool/checks/T-0030-AC7_closure.sh" > "$log" 2>&1; then
  report "## T-0030 closure check re-run: PASS" '```' "$(grep -E '^##|Flutter markers|PASS|FAIL' "$log")" '```'
else
  report "## T-0030 closure check re-run: FAIL" '```' "$(tail -20 "$log")" '```'
  rc=1
fi
rm -f "$log"

tops="$(cd utility/mc_media/lib && ls ./*.dart 2>/dev/null | tr '\n' ' ')"
report "## mc_media top-level barrels: ${tops:-none}"
[[ "$tops" == "./mc_media.dart " ]] || rc=1
[[ -f utility/mc_ds_media/lib/src/mc_media_scope.dart ]] || { report "missing mc_ds_media McMediaScope"; rc=1; }
[[ ! -e utility/mc_media/lib/mc_media_scope.dart ]] || { report "mc_media_scope.dart still exists"; rc=1; }
stale="$(grep -rn "mc_media/mc_media_scope\|:mc_media_scope" --include=BUILD.bazel --include=*.dart --include=*.yaml utility app feature 2>/dev/null | head)"
report "## stale references to the old barrel or library" '```' "${stale:-none}" '```'
[[ -z "$stale" ]] || rc=1
finish T-0031-AC6 $rc
