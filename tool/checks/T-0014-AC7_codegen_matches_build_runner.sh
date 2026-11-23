#!/bin/bash
# T-0014-AC6 / AC7: the stock freezed and go_router shims' outputs equal
# build_runner's byte for byte (tool/build_runner_overlay/spike_reference.sh),
# the freezed output declares when/maybeWhen/map, and the route codegen runs
# without analyzer summaries (the F-0007 workaround).
#   tool/checks/T-0014-AC7_codegen_matches_build_runner.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
log="$(mktemp)"
"$REPO/tool/build_runner_overlay/spike_reference.sh" spike/hello > "$log" 2>&1; rc=$?
frz="$("$BAZELW" info bazel-bin 2>/dev/null)/spike/hello/lib/src/counter_state.freezed.dart"
methods=$(grep -o -E 'TResult\?? (when|maybeWhen|map|maybeMap|whenOrNull|mapOrNull)<' "$frz" 2>/dev/null | sed -E 's/.* ([a-zA-Z]+)</\1/' | sort | tr '\n' ' ')
sums() { "$BAZELW" aquery "mnemonic(DartCodegen, //spike/hello:$1)" --output=text 2>/dev/null | grep -c -- '--summary' || true; }
s_routes=$(sums routes_go_router_part); s_frz=$(sums counter_state_freezed)
report "# T-0014-AC6 / AC7: Bazel codegen vs build_runner" "" '```' "$(grep -E '^(==|   |EQUAL|DIFFER|MISSING|DRIFT|UNRESOLVED)' "$log")" '```' "" \
  "- freezed pattern methods: $methods" \
  "- \`--summary\` args: routes_go_router_part $s_routes (must be 0), counter_state_freezed $s_frz"
rm -f "$log"
ok=0
[[ $rc -eq 0 && "$methods" == *"map "* && "$methods" == *"maybeWhen "* && "$methods" == *"when "* && "$s_routes" -eq 0 ]] && ok=1
finish T-0014-AC7 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
