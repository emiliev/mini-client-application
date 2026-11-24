#!/bin/bash
# T-0030-AC7: the closures of //utility/mc_paging and //utility/mc_media (the
# pure library) contain no Flutter and no sky_engine. Positive control: the
# closure of //utility/mc_media:mc_media_scope must show Flutter markers, so a
# query that cannot see Flutter fails the check.
#   MC_OUTPUT_BASE=/tmp/mc-ob-x tool/checks/T-0030-AC7_closure.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
bz() { "$BAZELW" ${MC_OUTPUT_BASE:+--output_base="$MC_OUTPUT_BASE"} "$@"; }
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
rc=0
report "# T-0030-AC7: pure closures" ""
for target in //utility/mc_paging:mc_paging //utility/mc_media:mc_media; do
  deps="$(bz cquery "deps($target)" 2>/dev/null | sed 's/ (.*//')"
  hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -10)"
  n="$(grep -c . <<< "$deps")"
  report "## $target ($n targets in the closure)" '```' "Flutter markers: ${hits:-none}" '```'
  [[ "$n" -lt 100 || -n "$hits" ]] && rc=1
done
control="$(bz cquery "deps(//utility/mc_media:mc_media_scope)" 2>/dev/null | sed 's/ (.*//' | grep -E "$FLUTTER" | sort -u | head -3)"
report "## positive control: //utility/mc_media:mc_media_scope" '```' "Flutter markers: ${control:-none}" '```'
[[ -z "$control" ]] && rc=1
finish T-0030-AC7 $rc
