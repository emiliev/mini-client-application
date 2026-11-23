#!/bin/bash
# T-0014-AC4 (H-CFGDUP): in one Bazel server, build the simulator app, then
# run the host widget test, and count DartKernel / DartCodegen actions
# duplicated across configurations from the two execution logs.
# Uses a throwaway --output_base (so the worktree's own server and outputs are
# untouched) and --config=cold (no disk cache), then deletes it. The shared
# repository cache means nothing is downloaded again.
#   tool/checks/T-0014-AC4_cfgdup_count.sh [--out FILE]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
TMP="$(mktemp -d)"
OB="$TMP/output_base"
cleanup() { "$BAZELW" --output_base="$OB" shutdown >/dev/null 2>&1; chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
"$BAZELW" --output_base="$OB" build --config=sim --config=cold \
  --execution_log_json_file="$TMP/exec_sim.json" //spike/hello:hello_ios > "$TMP/sim.log" 2>&1; rc_sim=$?
"$BAZELW" --output_base="$OB" test --config=cold \
  --execution_log_json_file="$TMP/exec_host.json" //spike/hello:widget_test > "$TMP/host.log" 2>&1; rc_host=$?
p_sim=$(plain "$TMP/sim.log" | grep -a 'processes:' | tail -1)
p_host=$(plain "$TMP/host.log" | grep -a 'processes:' | tail -1)
counts="$(/usr/bin/python3 -I "$REPO/tool/checks/cfgdup.py" "$TMP/exec_sim.json" "$TMP/exec_host.json" 2>&1)"; rc_py=$?
report "# T-0014-AC4: H-CFGDUP" "" \
  "Fresh output base, disk cache off. 1: \`build --config=sim //spike/hello:hello_ios\` (exit $rc_sim; $p_sim). 2: \`test //spike/hello:widget_test\` (exit $rc_host; $p_host)." \
  "" "$(grep -v '^MACHINE' <<< "$counts")"
machine="$(grep '^MACHINE' <<< "$counts")"
report "" "\`$machine\`"
total=$(sed -n 's/.*codegen_total=\([0-9]*\).*/\1/p' <<< "$machine")
ok=0
[[ $rc_sim -eq 0 && $rc_host -eq 0 && $rc_py -eq 0 && "${total:-0}" -gt 0 ]] && ok=1
finish T-0014-AC4 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
