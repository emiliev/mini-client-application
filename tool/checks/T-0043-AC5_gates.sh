#!/bin/bash
# T-0043-AC5: mc_fixtures_discovery is pure Dart, registered, covered at >= 90 %,
# and no production target reaches it; plus the repo gates.
#   1. closure of //utility/mc_fixtures_discovery:mc_fixtures_discovery has no Flutter
#      markers (as T-0030-AC7). Positive control: the closure of
#      //utility/mc_fixtures_characters has them (via mc_fixtures_media), so a
#      query that cannot see Flutter fails the check.
#   2. workspace registration in the root pubspec.yaml
#   3. fixtures check: no production feature or utility target reaches it
#      (T-0031-AC6 scan). Positive control: its own test target does.
#      Negative control: a dependency added to characters_list's BUILD is
#      detected.
#   4. gates: test //..., lint, mc_arch_check, rules_fork.sh check, format,
#      l10n_check
#   5. coverage of the package's lib/ >= MC_COVERAGE_MIN (default 90)
#   tool/checks/T-0043-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
MIN="${MC_COVERAGE_MIN:-90}"
FLUTTER='sky_engine|flutter_ios_engine|pub_deps__flutter[_a-z]*//|pub_deps__flutter_test|@@rules_flutter|//flutter:'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
rows=()
fails=()
ok=1
logname() { printf '%s/%s.log' "$work" "$(tr -c 'a-zA-Z0-9' _ <<< "$1")"; }
gate() {  # gate <name> <command...>
  local name="$1"; shift
  local log; log="$(logname "$name")"
  if "$@" > "$log" 2>&1; then
    rows+=("| $name | PASS |")
  else
    rows+=("| $name | **FAIL** |"); ok=0
    fails+=("" "### $name failed" "" '```' "$(plain "$log" | grep -a -v '^\[' | tail -25)" '```')
  fi
}
closure() { bzw cquery "deps($1)" 2>/dev/null | sed 's/ (.*//'; }

# 1. purity
deps="$(closure //utility/mc_fixtures_discovery:mc_fixtures_discovery)"
n="$(grep -c . <<< "$deps")"
hits="$(grep -E "$FLUTTER" <<< "$deps" | sort -u | head -5)"
# The positive control is the Flutter-bound media package: a query that
# cannot see Flutter would fail the check.
control="$(closure //utility/mc_fixtures_media:mc_fixtures_media | grep -E "$FLUTTER" | sort -u | head -3)"
report "# T-0043-AC5: pure Dart, registered, covered" "" \
  "## closure of mc_fixtures_discovery ($n targets)" '```' "Flutter markers: ${hits:-none}" '```' \
  "## positive control: mc_fixtures_media" '```' "Flutter markers: ${control:-none}" '```'
if [[ "$n" -ge 100 && -z "$hits" && -n "$control" ]]; then rows+=("| pure-Dart closure | PASS |"); else rows+=("| pure-Dart closure | **FAIL** |"); ok=0; fi

# 2. registration
if grep -qx '  - utility/mc_fixtures_discovery' pubspec.yaml; then rows+=("| workspace registration | PASS |"); else rows+=("| workspace registration | **FAIL** |"); ok=0; fi

# 3. no production target reaches it
libs=""
for d in feature/*/*/ utility/mc_*/; do
  pkg="$(basename "$d")"
  case "$pkg" in
    mc_fixtures_*|mc_mocked_backend|mc_test_*|mc_e2e_utils|mc_ds_testing|mc_analysis) continue ;;
  esac
  [[ -f "$d/BUILD.bazel" ]] || continue
  libs="$libs //${d%/}:$pkg"
done
scan() {
  local l out hit
  for l in "$@"; do
    out="$(closure "$l")"
    if [[ -z "$out" ]]; then echo "$l -> QUERY RETURNED NOTHING"; continue; fi
    hit="$(grep -E '^@?@?//utility/mc_fixtures_discovery' <<< "$out" | sort -u | head -3 | tr '\n' ' ')"
    [[ -z "$hit" ]] || echo "$l -> $hit"
  done
}
nlibs="$(wc -w <<< "$libs" | tr -d ' ')"
# shellcheck disable=SC2086
found="$(scan $libs)"
pos="$(closure //utility/mc_fixtures_discovery:search_test | grep -E '^@?@?//utility/mc_fixtures_discovery' | sort -u | head -2 | tr '\n' ' ')"
build=feature/characters/characters_list/BUILD.bazel
cp "$build" "$build.orig"
trap 'mv -f "$build.orig" "$build" 2>/dev/null; rm -rf "$work"' EXIT
sed -i '' 's|^    "//utility/mc_api_client",$|    "//utility/mc_api_client",\n    "//utility/mc_fixtures_discovery",|' "$build"
neg="$(scan //feature/characters/characters_list:characters_list)"
mv -f "$build.orig" "$build"
report "## fixtures check ($nlibs production targets scanned)" '```' \
  "discovery dependencies: ${found:-none}" "positive control (its own test): ${pos:-nothing}" \
  "negative control (dep added to characters_list): ${neg:-NOT DETECTED}" '```'
if [[ -z "$found" && "$nlibs" -ge 20 && -n "$pos" && -n "$neg" && "$neg" != *"QUERY RETURNED NOTHING"* ]]; then
  rows+=("| fixtures check | PASS |")
else
  rows+=("| fixtures check | **FAIL** |"); ok=0
fi

# 4. gates
# Two gates with their own logs, so the reported "Executed" line is the
# uncached discovery run, not the cached repo-wide run after it.
gate "test discovery (uncached)" bzw test --nocache_test_results //utility/mc_fixtures_discovery/...
gate "test //..." bzw test //...
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"

# 5. coverage
coverage() {
  bzw coverage //utility/mc_fixtures_discovery/... || return 1
  /usr/bin/python3 -I "$REPO/tool/checks/merge_lcov.py" \
    "$(bzw info output_path 2>/dev/null)" utility/mc_fixtures_discovery "$MIN" | tee "$work/coverage.txt"
}
gate "coverage >= $MIN %" coverage
total=$(grep -a '^TOTAL' "$work/coverage.txt" 2>/dev/null || echo 'TOTAL not measured')
tests_line=$(plain "$(logname "test discovery (uncached)")" 2>/dev/null | grep -a 'Executed' | tail -1)
all_line=$(plain "$(logname "test //...")" 2>/dev/null | grep -a 'Executed' | tail -1)

report "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- discovery tests, uncached: ${tests_line:-?}" "- test //...: ${all_line:-?}" "- mc_fixtures_discovery coverage: $total (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0043-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
