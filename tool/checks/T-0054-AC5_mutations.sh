#!/bin/bash
# T-0054-AC5: mutation check of the flow-result hardening (P-094 to P-098).
#
# Every mutation edits one source file, runs the named test targets, and must
# make a test FAIL ("FAILED in" in Bazel's summary). Three outcomes only:
#   KILLED    a test failed (and, where MUST is given, the named one).
#   BROKEN    the build did not complete ("Build did NOT complete", a compile
#             or format error): NOT evidence, counted as a failure of the run.
#   SURVIVED  every test passed: a hole in the tests.
# The unmutated tree must pass first. The script REFUSES a dirty tree (any
# uncommitted or untracked file), and sets its restore trap before it edits
# anything; every file is restored with `git checkout` after each mutation and
# the restore is verified.
#
#   MC_ROLE=engineer tool/checks/T-0054-AC5_mutations.sh
#   MC_ONLY="M01 V08" ...   only the named mutations (after the baseline)
#
# Exit 0 only if every mutation was applied and killed. The log goes to
# /tmp/mc-T-0054-<role>-mutations.log (a copy is kept in the evidence dir by
# the engineer).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-T-0054-$ROLE}"
LOG="/tmp/mc-T-0054-$ROLE-mutations.log"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the tree is dirty (commit or remove these first):" >&2
  git status --short >&2
  exit 2
fi
: > "$LOG"

AC=app/wiring/app_core
APP=app/mini_client
RES=$AC/lib/src/router/flow_results.dart
ROUTER=$APP/lib/src/router/app_router.dart
PAGES=$APP/lib/src/pages/placeholder_pages.dart
LISTS=app/wiring/library_wiring/lib/src/routes/reading_lists_routes.dart

T_RES=//$AC:flow_results_test
T_HARD=//$AC:flow_results_hardening_test
T_APP=//$APP:deep_link_back_stack_test
T_NF=//$APP:not_found_test
T_OLD="//$APP:app_test //$APP:comic_route_test //$APP:reading_list_route_test //$APP:links_after_flow_test //$APP:search_route_test"
T_LISTS=//app/wiring/library_wiring:routes_test

FILES=("$RES" "$ROUTER" "$PAGES" "$LISTS")
restore_all() { git checkout -- "${FILES[@]}" 2>/dev/null; }
trap restore_all EXIT INT TERM

run() { bz test --nocache_test_results --test_timeout=900 --test_output=all "$@" 2>&1 | tr '\r' '\n'; }

base="$(run $T_RES $T_HARD $T_APP $T_NF $T_OLD $T_LISTS)"
if grep -q -a -E "FAILED|NO STATUS|^ERROR|Build did NOT complete" <<< "$base"; then
  say "BASELINE FAILS"
  grep -a -E "FAILED|^ERROR|Build did NOT" <<< "$base" | tee -a "$LOG"
  exit 1
fi
say "baseline: PASS"

rc=0; n=0; killed=0
# mutate ID "what" file "targets" old new [old new ...]
# (MUST="substring" requires that a failing test's line contains it.)
mutate() {
  local id="$1" what="$2" file="$3" targets="$4"; shift 4
  if [[ -n "${MC_ONLY:-}" && " $MC_ONLY " != *" $id "* ]]; then return; fi
  n=$((n + 1))
  /usr/bin/python3 -I - "$file" "$@" <<'EOF'
import sys
path, pairs = sys.argv[1], sys.argv[2:]
s = open(path).read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if s.count(old) != 1:
        print("PATTERN MATCHES %d TIMES: %r" % (s.count(old), old)); sys.exit(3)
    s = s.replace(old, new)
open(path, "w").write(s)
EOF
  if [[ $? -ne 0 ]]; then
    say "$id $what: NOT APPLIED"; rc=1; git checkout -- "$file"; return
  fi
  [[ "$file" == *.dart ]] && fvm dart format "$file" > /dev/null
  local out; out="$(run $targets)"
  if grep -q -a -E "Build did NOT complete|^ERROR|FAILED TO BUILD" <<< "$out"; then
    say "$id $what: BROKEN (build failed: not evidence)"; rc=1
  elif grep -q -a "FAILED in" <<< "$out"; then
    local first; first="$(grep -a -m1 -E '^  FAIL  ' <<< "$out" | sed 's/^ *//')"
    if [[ -n "${MUST:-}" ]] && ! grep -a -E '^  FAIL  ' <<< "$out" | grep -q -F -- "$MUST"; then
      say "$id $what: KILLED, BUT NOT BY THE EXPECTED TEST ($MUST). First: $first"; rc=1
    else
      say "$id $what: KILLED ($first)"; killed=$((killed + 1))
    fi
  elif grep -q -a "TIMEOUT in" <<< "$out"; then
    say "$id $what: TIMEOUT (not a kill)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}

F="$T_RES $T_HARD"          # the flow-result tests
FA="$T_RES $T_HARD $T_APP"  # and the app's

# --- The Verifier's V08 (T-0049): the push future is no longer chained.
MUST="a redirected page that pops with a value" mutate V08 \
  "the push future is not chained into the call" "$RES" "$F" \
  $'    unawaited(\n      pushed.then((value) => call.complete(value is String ? value : null)),\n    );\n' ''

# --- P-094: the call, not the location
mutate M01 "the stack watch never abandons a call" "$RES" "$F" \
  'if (pageKey != null ? find() == null : superseded()) {' 'if (false) {'
mutate M02 "the page's key is never taken" "$RES" "$F" \
  $'        pageKey = match.pageKey.value;' $'        pageKey = null;'
mutate M03 "the stack is checked at once, not after the frame" "$RES" "$F" \
  $'      WidgetsBinding.instance\n        ..addPostFrameCallback((_) => check())\n        ..scheduleFrame();' \
  'check();'
mutate M04 "the page is first matched by nothing" "$RES" "$F" \
  '? push != null && identical(match.completer.future, push)' '? false'
mutate M05 "the stack watch is not listening" "$RES" "$F" \
  $'    delegate.addListener(onChange);\n' ''
mutate R1 "the page is matched by its completer, not its key (a re-parse abandons it)" "$RES" "$F" \
  ': match.pageKey.value == pageKey)' ': identical(match.completer.future, push))'
mutate R2 "the route drops its call when a re-parse gives it a null extra" "$RES" "$F" \
  $'    if (extra is FlowCall<T>) {\n      _call = extra;\n    }' $'    _call = extra is FlowCall<T> ? extra : null;'
mutate R3 "a push replaced in its own frame is never abandoned (no supersede check, no first look)" "$RES" "$F" \
  'if (pageKey != null ? find() == null : superseded()) {' 'if (pageKey != null ? find() == null : false) {' \
  $'    onChange();\n    return call.result;' $'    return call.result;'
mutate R5 "the listener is never removed" "$RES" "$F" \
  $'        delegate.removeListener(onChange);\n' ''
mutate R7 "a non-String pop value is cast, not dropped" "$RES" "$F" \
  'call.complete(value is String ? value : null)' 'call.complete(value as String?)'
mutate M07 "the debug assert never fires" "$RES" "$F" \
  'if (_call == null && state.extra is FlowCall) {' 'if (false) {'
mutate M08 "the debug assert fires on a go-built route (no extra)" "$RES" "$F" \
  'if (_call == null && state.extra is FlowCall) {' 'if (_call == null) {'
mutate M09 "a call completes twice (no guard)" "$RES" "$F" \
  $'    if (!_completer.isCompleted) {\n      _completer.complete(value);\n    }' \
  '    _completer.complete(value);'
# (Not mutated: the direct `_call?.complete(pending.value)` in `_deliver` is
# equivalent since the call also holds the result; it stays as an explicit
# guard against microtask order.)

# --- P-096: a held result is delivered
mutate M11 "an abandoned call ends with null even when it held a result" "$RES" "$F" \
  'void abandon() => complete(_held?.value);' 'void abandon() => complete(null);'
mutate M12 "the route does not tell the call what it holds" "$RES" "$F" \
  $'    _call?._hold(result);\n' ''
mutate M13 "dispose ends the call with null" "$RES" "$F" \
  $'    _call?.abandon();\n    super.dispose();' $'    _call?.complete(null);\n    super.dispose();'

# --- P-095: the extra codec
mutate M14 "the codec drops every extra" "$RES" "$F" \
  'if (_isJsonSafe(input, 0)) {' 'if (false) {'
mutate M15 "the codec keeps every extra" "$RES" "$F" \
  'if (_isJsonSafe(input, 0)) {' 'if (true) {'
mutate M16 "the codec never warns" "$RES" "$F" \
  'if (_encoding && _warnedExtraTypes.add(input.runtimeType)) {' 'if (false) {'
mutate M17 "the codec warns every time" "$RES" "$F" \
  'if (_encoding && _warnedExtraTypes.add(input.runtimeType)) {' 'if (_encoding) {'
mutate M18 "the codec keeps a FlowCall" "$RES" "$F" \
  'if (input == null || input is FlowCall) {' 'if (input == null) {'
mutate M19 "no depth limit" "$RES" "$F" \
  $'    if (depth > 32) {\n      return false;\n    }\n' ''
mutate M20 "NaN and infinity are JSON-safe" "$RES" "$F" \
  'final num n => n.isFinite,' 'final num _ => true,'
mutate M21 "map keys are not checked" "$RES" "$F" \
  '(e) => e.key is String && _isJsonSafe(e.value, depth + 1),' '(e) => _isJsonSafe(e.value, depth + 1),'
mutate M22 "a list is never JSON-safe" "$RES" "$F" \
  'final List<Object?> list => list.every((e) => _isJsonSafe(e, depth + 1)),' 'final List<Object?> _ => false,'

# --- P-097: not-found
mutate N01 "no onException: unknown paths use go_router's own page" "$ROUTER" "$T_NF $T_OLD" \
  $'  onException: (context, state, router) =>\n      router.go(notFoundLocation(_asked(state.uri))),\n' ''
mutate N02 "not-found keeps the scheme and host of a link" "$ROUTER" "$T_NF" \
  $'String _asked(Uri uri) => Uri(\n  path: uri.path,' $'String _asked(Uri uri) => uri.toString();\nString _unused(Uri uri) => Uri(\n  path: uri.path,'
mutate N11 "not-found loses the fragment" "$ROUTER" "$T_NF" \
  'fragment: uri.hasFragment ? uri.fragment : null,' 'fragment: null,'
mutate N03 "not-found loses the query" "$ROUTER" "$T_NF" \
  'query: uri.hasQuery ? uri.query : null' 'query: null'
mutate N04 "the not-found route shows no location" "$ROUTER" "$T_NF $T_OLD" \
  $'NotFoundPage(location: state.uri.queryParameters[\'from\'] ?? \'\'),' $'const NotFoundPage(location: \'\'),'
mutate N05 "a failed link goes home, not to not-found" "$ROUTER" "$T_NF $T_OLD" \
  'router.go(notFoundLocation(_asked(state.uri)))' 'router.go(AppLocations.home)'
mutate N06 "Back always pops" "$PAGES" "$T_NF" \
  'if (GoRouter.of(context).canPop()) {' 'if (true) {'
mutate N07 "Back always goes home" "$PAGES" "$T_NF" \
  'if (GoRouter.of(context).canPop()) {' 'if (false) {'
mutate N08 "Go home does nothing" "$PAGES" "$T_NF" \
  $'            label: \'Go home\',\n            onPressed: () => _home(context),' $'            label: \'Go home\',\n            onPressed: () {},'
mutate N09 "home is the characters list" "$PAGES" "$T_NF" \
  'GoRouter.of(context).go(AppLocations.home);' 'GoRouter.of(context).go(AppLocations.characters);'
mutate N10 "no Go home label" "$PAGES" "$T_NF" \
  "label: 'Go home'," "label: 'Home',"

# --- P-098: a link must be a go (the AC4 test of /characters/<id>). Only that
# test runs: under a push, the other deep-link tests wait out their timeouts.
MUST="T-0054-AC4 a link to the running app (/characters/100366)" mutate P1 \
  "a link is a push, not a go (the stack keeps what was open)" "$ROUTER" "$T_APP --test_filter=T-0054-AC4" \
  $'  overridePlatformDefaultLocation: true,\n' \
  $'  overridePlatformDefaultLocation: true,\n  onEnter: (c, cur, next, r) { if (cur.uri.toString().isEmpty || _p.contains(next.uri.toString())) return const Allow(); _p.add(next.uri.toString()); return Block.then(() => r.push(next.uri.toString())); },\n' \
  'GoRouter buildAppRouter' $'final _p = <String>{};\nGoRouter buildAppRouter'

# --- the routes still hand their extra over
mutate V11 "the library edit route forgets its extra" "$LISTS" "$T_LISTS //$APP:reading_list_route_test $T_RES" \
  $'      FlowResultRoute<String>(\n        extra: state.extra,\n        builder: (complete) => diContainer<LibraryRouteTargets>()\n            .editReadingList' \
  $'      FlowResultRoute<String>(\n        builder: (complete) => diContainer<LibraryRouteTargets>()\n            .editReadingList'

say "mutations: $n, killed: $killed"
if [[ $n -eq $killed && $rc -eq 0 ]]; then say "ALL KILLED"; exit 0; fi
say "SOME NOT KILLED"
exit 1
