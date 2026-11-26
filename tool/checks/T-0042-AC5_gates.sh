#!/bin/bash
# T-0042-AC5: the gates, run on the SYNCED tree (tool/ide_sync --env dev first),
# in one check that fails when any of them fails.
#   1. test //...
#   2. build --config=lint //...
#   3. run //tool/mc_arch_check:bin
#   4. tool/rules_fork.sh check
#   5. dart format --set-exit-if-changed (every Dart dir but tool/loc, P-066,
#      and third_party/)
#   6. run //tool/l10n_check:bin over the repo
#   7. the script tests of tool/ide_sync (tool/checks/T-0042-AC5_script_tests.sh)
#   8. the T-0032 byte-identity check (Bazel codegen equals build_runner), run
#      with the synced files present
#   tool/checks/T-0042-AC5_gates.sh [--out FILE] [--role R]
# MC_BAZEL_STARTUP holds extra Bazel startup options (e.g. --output_base=...);
# MC_OUTPUT_BASE is passed on to tool/ide_sync and the sub-checks.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
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
gate "tool/ide_sync --env dev (the gates run on the synced tree)" "$REPO/tool/ide_sync" --env dev
nsync=$(wc -l <"$REPO/.dart_tool/mc_ide_sync.manifest" | tr -d ' ')
gate "test //... (synced tree)" bzw test //...
gate "build --config=lint //..." bzw build --config=lint //...
gate "mc_arch_check" bzw run //tool/mc_arch_check:bin
gate "rules_fork.sh check" "$REPO/tool/rules_fork.sh" check
gate "dart format" fvm dart format --output=none --set-exit-if-changed \
  app feature spike utility tool/l10n_check tool/mc_arch_check
gate "l10n_check" bzw run //tool/l10n_check:bin -- "$REPO"
gate "ide_sync script tests (T-0042-AC5)" "$REPO/tool/checks/T-0042-AC5_script_tests.sh"
gate "T-0032-AC6 byte-identity with build_runner (synced tree)" "$REPO/tool/checks/T-0032-AC6_matches_build_runner.sh"
tests_line=$(plain "$(logname "test //... (synced tree)")" 2>/dev/null | grep -a 'Executed' | tail -1)

report "# T-0042-AC5: gates on the synced tree ($nsync synced files)" "" "| Gate | Result |" "|---|---|" "${rows[@]}" "" \
  "- tests: ${tests_line:-?}" \
  ${fails[@]+"${fails[@]}"}
finish T-0042-AC5-gates $([[ $ok -eq 1 ]] && echo 0 || echo 1)
