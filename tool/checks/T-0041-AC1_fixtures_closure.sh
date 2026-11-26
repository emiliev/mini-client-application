#!/bin/bash
# T-0041-AC1 (TL decision 2): the comics detail embeds its cast summary from
# mc_fixtures_characters, which T-0041 made pure Dart. Both fixture libraries'
# closures contain no Flutter and no sky_engine (as T-0030-AC7), and
# mc_fixtures_comics really depends on mc_fixtures_characters. Positive
# control: the closure of //utility/mc_fixtures_media (Flutter-bound) shows
# Flutter markers, so a query that cannot see Flutter fails the check.
#   tool/checks/T-0041-AC1_fixtures_closure.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
rc=0
report "# T-0041-AC1: the fixture domains the cast summary joins are pure Dart" ""
for target in //utility/mc_fixtures_characters:mc_fixtures_characters //utility/mc_fixtures_comics:mc_fixtures_comics; do
  deps="$(bzw cquery "deps($target)" 2>/dev/null | sed 's/ (.*//')"
  hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -10)"
  n="$(grep -c . <<< "$deps")"
  report "## $target ($n targets in the closure)" '```' "Flutter markers: ${hits:-none}" '```'
  [[ "$n" -lt 50 || -n "$hits" ]] && rc=1
done
link="$(bzw cquery "deps(//utility/mc_fixtures_comics:mc_fixtures_comics)" 2>/dev/null | sed 's/ (.*//' | grep -cx '//utility/mc_fixtures_characters:mc_fixtures_characters')"
report "## mc_fixtures_comics depends on mc_fixtures_characters: $link"
[[ "$link" -ge 1 ]] || rc=1
control="$(bzw cquery "deps(//utility/mc_fixtures_media:mc_fixtures_media)" 2>/dev/null | sed 's/ (.*//' | grep -E "$FLUTTER" | sort -u | head -3)"
report "## positive control: //utility/mc_fixtures_media" '```' "Flutter markers: ${control:-none}" '```'
[[ -z "$control" ]] && rc=1
finish T-0041-AC1-fixtures-closure $rc
