#!/bin/bash
# T-0035-AC4: the gates and the coverage threshold, in one check that fails
# when any of them fails.
#   1. test //...                      (uncached for mc_feature_flow, the vendored
#                                       flow_builder and characters_list)
#   2. build --config=lint //...
#   3. run //tool/mc_arch_check:bin
#   4. tool/rules_fork.sh check
#   5. dart format --set-exit-if-changed (every Dart dir but tool/loc, P-066,
#      and third_party/: vendored code keeps upstream's formatting)
#   6. run //tool/l10n_check:bin over the repo
#   7. coverage of mc_feature_flow and characters_list >= MC_COVERAGE_MIN
#      (default 90, ADR-0010): `bazel coverage //feature/...`, then the union
#      of the per-target LCOV (tool/checks/merge_lcov.py)
#   tool/checks/T-0035-AC4_gates.sh [--out FILE] [--role R]
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
uncached=(//feature/characters/characters_list/... //utility/mc_feature_flow/... //third_party/flow_builder/...)
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
gate "flow_builder provenance (evergreen)" "$REPO/tool/checks/T-0035-AC4_provenance.sh"
PKGS=(utility/mc_feature_flow feature/characters/characters_list)
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

report "# T-0035-AC4: gates and coverage" "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- tests: ${tests_line:-?}" "- coverage: $total (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0035-AC4-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
