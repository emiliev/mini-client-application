#!/bin/bash
# T-0036 Verifier: mutate McFlowBackButton one condition at a time and run the
# committed tests that could kill it. Reports killed / SURVIVED / COMPILE ERROR.
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a9c18a5ca6a657e99
cd "$W" || exit 2
F=utility/mc_feature_flow/lib/src/flow_context.dart
trap 'git -C "$W" checkout -- "$F"' EXIT
TARGETS=(//utility/mc_feature_flow/... //feature/characters/characters_list/... //app/...)
mut() {  # mut <name> <old> <new>
  /usr/bin/python3 -I - "$F" "$2" "$3" <<'PY' || { echo "M $1: INVALID"; return; }
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if old not in s: sys.exit("not found")
open(p, "w").write(s.replace(old, new, 1))
PY
  local log="$S/mut_fb_$(tr -c 'a-zA-Z0-9' _ <<< "$1").log"
  if tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier test --test_output=errors "${TARGETS[@]}" >"$log" 2>&1; then
    echo "M $1: SURVIVED"
  elif tr '\r' '\n' < "$log" | grep -a -q 'Build did NOT complete'; then
    echo "M $1: COMPILE ERROR"
  else
    echo "M $1: killed by $(tr '\r' '\n' < "$log" | grep -a -E '^//.*FAILED' | sed 's/ .*//' | sort -u | tr '\n' ' ')"
    tr '\r' '\n' < "$log" | grep -a -E '^\s+FAIL ' | sed 's/^/      /' | sort -u | head -6
  fi
  git -C "$W" checkout -- "$F"
}
if [[ "${1:-}" == round2 ]]; then
mut "M1b isFirst ignored (any route counts as root)" "final isFlowRoot = ModalRoute.of(context)?.isFirst ?? false;" "final isFlowRoot = ModalRoute.of(context) != null;"
mut "M3b pops the inner navigator" "    return BackButton(onPressed: () => unawaited(outer.maybePop()));" "    final inner = Navigator.of(context);
    return BackButton(onPressed: () => unawaited(inner.maybePop()));"
mut "M4b root check inverted" "if (!isFlowRoot || outer == null" "if (isFlowRoot || outer == null"
exit 0
fi
mut "M1 isFirst check dropped" "!isFlowRoot || outer == null" "outer == null"
mut "M2 canPop check dropped" "outer == null || !outer.canPop()" "outer == null"
mut "M3 pops the inner navigator" "unawaited(outer.maybePop())" "unawaited(Navigator.of(context).maybePop())"
mut "M4 always empty" "if (!isFlowRoot ||" "if (true ||"
mut "M5 isFirst -> isCurrent" "?.isFirst ?? false" "?.isCurrent ?? false"
mut "M6 maybePop -> pop (ignores PopScope)" "unawaited(outer.maybePop())" "outer.pop()"
mut "M7 no route counts as root" "?.isFirst ?? false" "?.isFirst ?? true"
mut "M8 canPop read from the inner navigator" "!outer.canPop()" "!Navigator.of(context).canPop()"
