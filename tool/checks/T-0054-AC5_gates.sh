#!/bin/bash
# T-0054-AC5: the gates and the
# coverage threshold (app_core, mini_client and the wirings), in one check that fails when any of them fails.
#   1. test //...                      (uncached: //app/...)
#   2. build --config=lint //...
#   3. run //tool/mc_arch_check:bin
#   4. tool/rules_fork.sh check
#   5. dart format --set-exit-if-changed (every Dart dir but tool/loc, P-066,
#      and third_party/: vendored code keeps upstream's formatting)
#   6. run //tool/l10n_check:bin over the repo
#   7. the fixtures check (T-0031-AC6: no production feature or utility target
#      depends on mc_fixtures_*; library_reading_list_editor is found by its
#      glob) and the relative-path scan (T-0034-AC4)
#   8. the flow_builder provenance check (T-0035-AC4, evergreen)
#   9. coverage of every touched package with hand-written lib/ code >=
#      MC_COVERAGE_MIN (default 90, ADR-0010): `bazel coverage`, then the
#      union of the per-target LCOV (tool/checks/merge_lcov.py)
#   tool/checks/T-0054-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
MIN="${MC_COVERAGE_MIN:-90}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
rows=()
fails=()
ok=1
logname() { printf '%s/%s.log' "$work" "$(tr -c 'a-zA-Z0-9' _ <<< "$1")"; }
gate() {  # gate <name> <command...>: runs it, records PASS/FAIL and its log tail
  local name="$1"; shift
  local log; log="$(logname "$name")"
  if "$@" > "$log" 2>&1; then
    rows+=("| $name | PASS |")
  else
    rows+=("| $name | **FAIL** |"); ok=0
    fails+=("" "### $name failed" "" '```' "$(plain "$log" | grep -a -v '^\[' | tail -25)" '```')
  fi
}
uncached=(//app/...)
tests() {
  bzw test --nocache_test_results "${uncached[@]}" && bzw test //...
}
gate "test //... (touched packages uncached)" tests
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"
# The closure checks take the output base on their own variable.
ob=""
[[ "${MC_BAZEL_STARTUP:-}" == --output_base=* ]] && ob="${MC_BAZEL_STARTUP#--output_base=}"
gate "fixtures check (T-0031-AC6)" env MC_OUTPUT_BASE="$ob" "$REPO/tool/checks/T-0031-AC6_closure.sh"
gate "relative API paths (T-0034-AC4)" "$REPO/tool/checks/T-0034-AC4_relative_paths.sh"
gate "flow_builder provenance (T-0035-AC4)" "$REPO/tool/checks/T-0035-AC4_provenance.sh"
PKGS=(app/mini_client app/wiring/app_core app/wiring/library_wiring app/wiring/publishing_wiring app/wiring/universe_wiring app/wiring/discovery_wiring)
EXEMPT="${MC_COVERAGE_EXEMPT-}"
coverage() {
  local pkg rc=0
  : > "$work/coverage.txt"
  bzw coverage $(printf '//%s/... ' "${PKGS[@]}") || return 1
  for pkg in "${PKGS[@]}"; do
    echo "== $pkg" >> "$work/coverage.txt"
    /usr/bin/python3 -I "$REPO/tool/checks/merge_lcov.py" \
      "$(bzw info output_path 2>/dev/null)" "$pkg" "$MIN" >> "$work/coverage.txt" || {
      if [[ " $EXEMPT " == *" $pkg "* ]]; then echo "UNDER $MIN (exempt, pre-existing): $pkg" >> "$work/coverage.txt"
      else echo "UNDER $MIN: $pkg" >> "$work/coverage.txt"; rc=1; fi; }
  done
  cat "$work/coverage.txt"
  return $rc
}
gate "coverage >= $MIN % (touched packages)" coverage
total=$(grep -a -E '^(==|TOTAL|UNDER)' "$work/coverage.txt" 2>/dev/null | paste -sd" " - || echo 'not measured')
tests_line=$(plain "$(logname "test //... (touched packages uncached)")" 2>/dev/null | grep -a 'Executed' | tail -1)

report "# T-0054-AC5: gates and coverage" "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- tests: ${tests_line:-?}" "- coverage: $total (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0054-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
