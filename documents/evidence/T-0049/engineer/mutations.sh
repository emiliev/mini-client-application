#!/bin/bash
# T-0049 mutation check. Each mutation must make a named test target FAIL
# with a failing test (a compile error is not evidence). The unmutated tree
# must pass first. Restores each file with `git checkout` and verifies it;
# REFUSES to run when a mutated file has uncommitted edits.
#
#   MC_TASK=T-0049 MC_ROLE=engineer documents/evidence/T-0049/engineer/mutations.sh
#   MC_ONLY="N1 R2" ...   only the named mutations (after the baseline)
#
# Exit 0 only if every mutation was applied and killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK}"
: "${MC_ROLE:?set MC_ROLE}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log"
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

AC=app/wiring/app_core
APP=app/mini_client
ROUTER=$APP/lib/src/router/app_router.dart
RESULTS_SRC=$AC/lib/src/router/flow_results.dart
NESTING=$AC/lib/src/router/route_nesting.dart
LISTS=app/wiring/library_wiring/lib/src/routes/reading_lists_routes.dart
HOME_PAGE=$APP/lib/src/pages/placeholder_pages.dart

T_APP=//$APP:deep_link_back_stack_test
T_RESULTS=//$AC:flow_results_test
T_NEST=//$AC:route_nesting_test
T_LISTS=//app/wiring/library_wiring:routes_test
T_OLD="//$APP:reading_list_route_test //$APP:comic_route_test //$APP:search_route_test //$APP:links_after_flow_test //$APP:app_test"

FILES=($ROUTER $RESULTS_SRC $NESTING $LISTS $HOME_PAGE)
for f in "${FILES[@]}"; do
  if ! git diff --quiet -- "$f" || ! git diff --cached --quiet -- "$f"; then
    say "REFUSING TO RUN: $f has uncommitted edits (commit them first)"; exit 2
  fi
done
restore_all() { git checkout -- "${FILES[@]}"; }
trap restore_all EXIT

run() { bz test --nocache_test_results --test_output=all "$@" 2>&1 | tr '\r' '\n'; }

base="$(run $T_APP $T_RESULTS $T_NEST $T_LISTS $T_OLD)"
if grep -q -E "FAILED|NO STATUS|^ERROR" <<< "$base"; then
  say "BASELINE FAILS"; grep -E "FAILED|^ERROR" <<< "$base" | tee -a "$LOG"; exit 1
fi
say "baseline: PASS"

rc=0; n=0; killed=0
mutate() {
  local id="$1" what="$2" file="$3" expr="$4"; shift 4
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then return; fi
  n=$((n + 1))
  /usr/bin/python3 -I - "$file" "$expr" <<'EOF'
import re, sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p).read()
t = eval(expr)
if t == s:
    print("MUTATION DID NOT CHANGE THE FILE"); sys.exit(3)
open(p, "w").write(t)
EOF
  if [[ $? -ne 0 ]]; then say "$id $what: NOT APPLIED"; rc=1; git checkout -- "$file"; return; fi
  [[ "$file" == *.dart ]] && fvm dart format "$file" > /dev/null
  local out; out="$(run "$@")"
  local first; first="$(grep -a -m1 -E '^  FAIL  |^[0-9:]+ \+[0-9]+ -[0-9]+: ' <<< "$out" | sed 's/^ *//')"
  if [[ -n "$first" ]]; then
    say "$id $what: KILLED ($first)"; killed=$((killed + 1))
  elif grep -q -a -E "^ERROR|FAILED TO BUILD|Build did NOT complete" <<< "$out"; then
    say "$id $what: COMPILE ERROR (not evidence)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}

# top_level <group>: the python expression that takes `...<group>Routes` out
# of the nested list and puts it back at the router's top level.
top_level() {
  printf "s.replace('    ...%sRoutes,\\\\n', '').replace('routes: nestUnderHome(\$appRoutes, [', 'routes: [...%sRoutes, ...nestUnderHome(\$appRoutes, [').replace('  ]),\\\\n  // The auth', '  ])],\\\\n  // The auth')" "$1" "$1"
}

# --- AC1/AC2: the nesting ---------------------------------------------------
mutate N1 "a route back at the top level: comics (publishing)" $ROUTER "$(top_level publishing)" $T_APP
mutate N2 "a route back at the top level: search (discovery)" $ROUTER "$(top_level discovery)" $T_APP
mutate N3 "a route back at the top level: characters (universe)" $ROUTER "$(top_level universe)" $T_APP
mutate N4 "a route back at the top level: reading-list editor (library)" $ROUTER "$(top_level library)" $T_APP
mutate N5 "nestUnderHome keeps the leading slash (absolute child)" $NESTING \
  "s.replace('path: route.path.substring(1)', 'path: route.path')" $T_NEST $T_APP
mutate N6 "nestUnderHome drops a route's children" $NESTING \
  "s.replace('routes: route.routes);', 'routes: const []);')" $T_NEST $T_APP
mutate N7 "nestUnderHome drops home's own children" $NESTING \
  "s.replace('routes: [...home.routes, ...entityRoutes.map(_relative)],', 'routes: [...entityRoutes.map(_relative)],')" $T_NEST
# --- AC3: the result future always completes ---------------------------------
mutate R1 "FlowResultRoute does not complete the caller when disposed" $RESULTS_SRC \
  "s.replace('    _call?.complete(null);\n    super.dispose();', '    super.dispose();')" $T_RESULTS $T_APP
mutate R2 "the wiring route does not pass its extra (no FlowCall)" $LISTS \
  "s.replace('        extra: state.extra,\n', '')" $T_APP
mutate R3 "FlowCall completes twice (second value wins)" $RESULTS_SRC \
  "s.replace('    if (!_completer.isCompleted) {\n      _completer.complete(value);\n    }', '    _completer.complete(value);')" $T_RESULTS
mutate R4 "home never clears its guard" $HOME_PAGE \
  "s.replace('      _awaiting = false;', '      _awaiting = _awaiting;')" $T_APP

# --- review round: exact stacks, the debug assert, the codec, direct completion
mutate P1 "a link is a push, not a go (the stack keeps what was open)" $ROUTER \
  "s.replace('  overridePlatformDefaultLocation: true,\n', '  overridePlatformDefaultLocation: true,\n  onEnter: (c, cur, next, r) { if (cur.uri.toString().isEmpty || _p.contains(next.uri.toString())) return const Allow(); _p.add(next.uri.toString()); return Block.then(() => r.push(next.uri.toString())); },\n').replace('GoRouter buildAppRouter', 'final _p = <String>{};\nGoRouter buildAppRouter')" $T_APP
mutate R5 "no direct completion before the pop (result depends on microtask order)" $RESULTS_SRC \
  "s.replace('    _call?.complete(pending.value);\n', '')" $T_RESULTS
mutate R6 "a forgotten extra no longer trips the debug assert" $RESULTS_SRC \
  "s.replace('    if (_call == null && expected > 0) {', '    if (_call == null && expected < 0) {')" $T_RESULTS
mutate R7 "the codec keeps a FlowCall (warning, lost on restore)" $RESULTS_SRC \
  "s.replace('input is FlowCall ? null : input', 'input')" $T_RESULTS
mutate R8 "the app router has no extraCodec" $ROUTER \
  "s.replace('  extraCodec: const FlowExtraCodec(),\n', '')" $T_APP
mutate N8 "nestUnderHome accepts a second route at exactly /" $NESTING \
  "s.replace(\" || route.path == '/') {\", ') {')" $T_NEST

say "mutations: $n, killed: $killed"
if [[ $n -eq $killed && $rc -eq 0 ]]; then say "ALL KILLED"; else say "SOME NOT KILLED"; fi
exit $rc
