#!/bin/bash
# T-0058-AC5: the gates and the coverage threshold, in one check that fails
# when any of them fails.
#   1. test //...                      (uncached for mc_feature_flow, the vendored
#                                       flow_builder and characters_list)
#   2. build --config=lint //...
#   3. run //tool/mc_arch_check:bin
#   4. tool/rules_fork.sh check
#   5. dart format --set-exit-if-changed (every Dart dir but tool/loc, P-066,
#      and third_party/: vendored code keeps upstream's formatting)
#   6. run //tool/l10n_check:bin over the repo
#   7. no direct showDialog / showModalBottomSheet / showSnackBar in lib code
#      (T-0058-AC4_no_direct_overlays.sh, with its controls)
#   8. coverage of mc_ds_overlays >= MC_COVERAGE_MIN (default 90, ADR-0010):
#      `bazel coverage` of //utility/mc_ds_overlays/..., then the union of the
#      per-target LCOV (tool/checks/merge_lcov.py)
#   tool/checks/T-0058-AC5_gates.sh [--out FILE] [--role R]
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
uncached=(//feature/characters/characters_list/... //utility/mc_feature_flow/... //utility/mc_ds_overlays/... //utility/mc_test_steps/... //app/wiring/app_core/... //third_party/flow_builder/...)
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
gate "fixtures closure (T-0031-AC6, covers mc_ds_overlays)" env MC_OUTPUT_BASE="${MC_OUTPUT_BASE:-/tmp/mc-ob-T-0058-$ROLE}" "$REPO/tool/checks/T-0031-AC6_closure.sh"
gate "no direct overlay calls (T-0058-AC4)" "$REPO/tool/checks/T-0058-AC4_no_direct_overlays.sh"
gate "layering (T-0058-AC5, re-runs T-0044-AC4 and T-0040-AC3)" "$REPO/tool/checks/T-0058-AC5_layering.sh"
PKGS=(utility/mc_ds_overlays)
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

report "# T-0058-AC5: gates and coverage" "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- tests: ${tests_line:-?}" "- coverage: $total (threshold $MIN %)" \
  ${fails[@]+"${fails[@]}"}
finish T-0058-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
