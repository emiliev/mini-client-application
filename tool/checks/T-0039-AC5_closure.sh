#!/bin/bash
# T-0039-AC5: the closures of //utility/mc_session, //utility/mc_api_auth and
# //utility/mc_fixtures_identity contain no Flutter and no sky_engine (R15,
# F-0019: a dio dependency can pull Flutter in through the dio cycle merge).
# Positive control: the closure of //utility/mc_ds_media:mc_ds_media must show
# Flutter markers, so a query that cannot see Flutter fails the check. Each
# closure must also be large enough to be a real query result.
#   MC_OUTPUT_BASE=/tmp/mc-ob-x tool/checks/T-0039-AC5_closure.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
bz() { "$BAZELW" ${MC_OUTPUT_BASE:+--output_base="$MC_OUTPUT_BASE"} "$@"; }
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
rc=0
report "# T-0039-AC5: pure closures" ""
for target in //utility/mc_session:mc_session //utility/mc_api_auth:mc_api_auth \
  //utility/mc_fixtures_identity:mc_fixtures_identity; do
  deps="$(bz cquery "deps($target)" 2>/dev/null | sed 's/ (.*//')"
  hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -10)"
  n="$(grep -c . <<< "$deps")"
  report "## $target ($n targets in the closure)" '```' "Flutter markers: ${hits:-none}" '```'
  # mc_fixtures_identity depends on the mocked backend only (a smaller closure).
  [[ "$n" -lt 50 || -n "$hits" ]] && rc=1
done
control="$(bz cquery "deps(//utility/mc_ds_media:mc_ds_media)" 2>/dev/null | sed 's/ (.*//' | grep -E "$FLUTTER" | sort -u | head -3)"
report "## positive control: //utility/mc_ds_media:mc_ds_media" '```' "Flutter markers: ${control:-none}" '```'
[[ -z "$control" ]] && rc=1
finish T-0039-AC5 $rc
