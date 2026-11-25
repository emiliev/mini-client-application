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

# No production mc_ds_* target depends on mc_fixtures_*. Positive control: a
# test target of mc_ds_media does (so a query that cannot see it fails).
bz() { "$BAZELW" ${MC_OUTPUT_BASE:+--output_base="$MC_OUTPUT_BASE"} "$@"; }
libs=""
for d in utility/mc_ds_*/; do
  pkg="$(basename "$d")"
  [[ -f "$d/BUILD.bazel" ]] || continue
  libs="$libs //utility/$pkg:$pkg"
done
fixtures_hits=""
nlibs=0
for l in $libs; do
  out="$(bz cquery "deps($l)" 2>/dev/null | sed 's/ (.*//')"
  [[ -n "$out" ]] || { report "query for $l returned nothing"; rc=1; continue; }
  nlibs=$((nlibs + 1))
  hit="$(grep -E '^@?@?//utility/mc_fixtures_' <<< "$out" | sort -u | head -3 | tr '\n' ' ')"
  [[ -z "$hit" ]] || fixtures_hits="$fixtures_hits $l -> $hit;"
done
report "## production mc_ds_* targets checked ($nlibs): $libs"
report '```' "fixtures dependencies: ${fixtures_hits:-none}" '```'
[[ -z "$fixtures_hits" && "$nlibs" -ge 6 ]] || rc=1
control="$(bz cquery "deps(//utility/mc_ds_media:image_test)" 2>/dev/null | sed 's/ (.*//' | grep -E '^@?@?//utility/mc_fixtures_' | sort -u | head -3 | tr '\n' ' ')"
report "## positive control: //utility/mc_ds_media:image_test (a test) depends on: ${control:-nothing}"
[[ -n "$control" ]] || rc=1
finish T-0031-AC6 $rc
