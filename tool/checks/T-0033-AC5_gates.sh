#!/bin/bash
# T-0033-AC5: the gates and the fixtures closure check, in one check that fails
# when either fails.
#   1. test //...   (uncached for the T-0033 packages: universe_wiring,
#                    universe_sandbox, mini_client, app_core)
#   2. build --config=lint //...
#   3. run //tool/mc_arch_check:bin
#   4. tool/rules_fork.sh check
#   5. dart format --set-exit-if-changed
#   6. run //tool/l10n_check:bin over the repo
#   7. tool/checks/T-0031-AC6_closure.sh: no feature or utility target
#      (fixtures, mocked backend and test utilities aside) depends on
#      mc_fixtures_*; fixtures only under //app/...
#   8. both apps build for the simulator (--config=sim)
#   tool/checks/T-0033-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...).
# Negative control: MC_GATES_NEGATIVE=1 plants a mc_fixtures_characters
# dependency in characters_list's BUILD, runs only gate 7, and the script must
# then exit 1 (its own exit code is 0 when it does, so a CI line can use it).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
work="$(mktemp -d)"
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
output_base=""
for opt in ${MC_BAZEL_STARTUP:-}; do
  case "$opt" in --output_base=*) output_base="${opt#--output_base=}" ;; esac
done
fixtures_closure() {
  MC_OUTPUT_BASE="$output_base" "$REPO/tool/checks/T-0031-AC6_closure.sh"
}

build=feature/characters/characters_list/BUILD.bazel
if [[ "${MC_GATES_NEGATIVE:-}" == 1 ]]; then
  cp "$build" "$work/BUILD.orig"
  trap 'cp "$work/BUILD.orig" "$build"; rm -rf "$work"' EXIT
  sed -i '' 's|^    "//utility/mc_api_client",$|    "//utility/mc_api_client",\n    "//utility/mc_fixtures_characters",|' "$build"
  gate "fixtures closure (negative control: planted dependency)" fixtures_closure
  cp "$work/BUILD.orig" "$build"
  report "# T-0033-AC5 negative control" "" "| Gate | Result |" "|---|---|" "${rows[@]}"
  if [[ $ok -eq 0 ]]; then
    report "" "The planted fixtures dependency was caught: the gate failed as it must."
    finish T-0033-AC5-negative 0
  fi
  report "" "The planted fixtures dependency was NOT caught."
  finish T-0033-AC5-negative 1
fi
trap 'rm -rf "$work"' EXIT

uncached=(//app/wiring/universe_wiring/... //app/sandbox/universe_sandbox/... //app/mini_client/... //app/wiring/app_core/...)
tests() {
  bzw test --nocache_test_results "${uncached[@]}" && bzw test //...
}
gate "test //... (T-0033 packages uncached)" tests
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check tool/e2e
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"
gate "fixtures closure (T-0031-AC6 widened)" fixtures_closure
gate "apps build for the simulator" bzw build --config=sim \
  //app/mini_client:mini_client_ios //app/sandbox/universe_sandbox:universe_sandbox_ios

tests_line=$(plain "$(logname "test //... (T-0033 packages uncached)")" 2>/dev/null | grep -a 'Executed' | tail -1)
report "# T-0033-AC5: gates and fixtures closure" "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- tests: ${tests_line:-?}" ${fails[@]+"${fails[@]}"}
finish T-0033-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
