#!/bin/bash
# T-0036 Verifier, re-verification at cbadeb0: my earlier McFlowBackButton
# mutations re-expressed for the new code, plus the new branches. Runs the
# committed tests only. Reports killed / SURVIVED / COMPILE ERROR.
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
  fvm dart format "$F" >/dev/null 2>&1
  local log="$S/rvmut_$(tr -c 'a-zA-Z0-9' _ <<< "$1").log"
  if tool/bazelw --output_base=/tmp/mc-ob-T-0036-verifier test --test_output=errors "${TARGETS[@]}" >"$log" 2>&1; then
    echo "M $1: SURVIVED"
  elif tr '\r' '\n' < "$log" | grep -a -q 'Build did NOT complete'; then
    echo "M $1: COMPILE ERROR"
    tr '\r' '\n' < "$log" | grep -a -E ' - ' | grep -a -E 'error|warning|info' | head -2 | sed 's/^/      /'
  else
    echo "M $1: killed by $(tr '\r' '\n' < "$log" | grep -a -E '^//.*FAILED' | sed 's/ .*//' | sort -u | tr '\n' ' ')"
    tr '\r' '\n' < "$log" | grep -a -E '^\s+FAIL ' | sed 's/^/      /' | sort -u | head -4
  fi
  git -C "$W" checkout -- "$F"
}
mut "M1b isFirst ignored (every route is the flow root)" "    if (route.isFirst) {" "    if (route.isActive) {"
mut "M1c isFirst -> isCurrent" "    if (route.isFirst) {" "    if (route.isCurrent) {"
mut "M2 root ignores outer.canPop()" "if (outer != null && outer.canPop()) {" "if (outer != null) {"
mut "M3b root pops the inner navigator" "        return BackButton(onPressed: () => unawaited(outer.maybePop()));" "        return BackButton(
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
        );"
mut "M6 root uses pop (ignores PopScope)" "unawaited(outer.maybePop())" "outer.pop()"
mut "M7 no route renders a BackButton" "    if (route == null) {
      return const SizedBox.shrink();
    }" "    if (route == null) {
      return const BackButton();
    }"
mut "M8 root canPop from the inner navigator" "outer != null && outer.canPop()" "outer != null && Navigator.of(context).canPop()"
mut "M9 off-root drawer dropped" "    if (hasDrawer) {
      return const DrawerButton();
    }
    if (route.impliesAppBarDismissal" "    if (route.impliesAppBarDismissal"
mut "M10 app-root drawer dropped" "      return hasDrawer ? const DrawerButton() : const SizedBox.shrink();" "      return const SizedBox.shrink();"
mut "M11 fullscreen dialog gets BackButton" "          ? const CloseButton()" "          ? const BackButton()"
mut "M12 impliesAppBarDismissal ignored" "if (route.impliesAppBarDismissal && route.canPop) {" "if (route.canPop) {"
mut "M13 off-root always empty" "if (route.impliesAppBarDismissal && route.canPop) {" "if (route.impliesAppBarDismissal && !route.canPop) {"
mut "M14 off-root BackButton pops the flow" "          : const BackButton();" "          : BackButton(
              onPressed: () => FlowScope.read(context).outerNavigator?.pop(),
            );"
