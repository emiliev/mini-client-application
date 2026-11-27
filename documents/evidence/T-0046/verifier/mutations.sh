#!/bin/bash
# T-0046 mutation check: one or more mutations per AC behaviour, and one per
# AC6 race (debounce, a stale answer, clearing or shortening the query while
# a request is in flight). Each must make a named test target FAIL with a
# failing test (a mutation that survives, or that only breaks the build,
# proves nothing). The unmutated tree must pass first (positive control).
# Each mutation is restored with `git checkout` of its file and the restore
# is verified; the script REFUSES to run when a file it mutates has
# uncommitted edits.
#
#   MC_TASK=T-0046 MC_ROLE=engineer documents/evidence/T-0046/engineer/mutations.sh
#   MC_ONLY="AC6-c AC6-d" ...   runs only the named mutations (after the baseline)
#
# Output base /tmp/mc-ob-$MC_TASK-$MC_ROLE; log /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log
# (also printed). Exit 0 only if every mutation was applied and killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK (e.g. T-0046)}"
: "${MC_ROLE:?set MC_ROLE (engineer or verifier)}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log"
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

DS=feature/discovery/discovery_search
DW=app/wiring/discovery_wiring
AC=app/wiring/app_core
BDD=//$DS:bdd_test
FLOW=//$DS:flow_scope_test
ARCH=//$DS:architecture_test
CONTRACT=//$DS:contract_test
GOLDEN=//$DS:golden_test
ROUTES=//$DW:routes_test
APP=//app/mini_client:search_route_test
BOOT=//$AC:boot_test

BLOC=$DS/lib/src/presentation/bloc/discovery_search_bloc.dart
MAP=$DS/lib/src/domain/model/search_mapper.dart
DTO=$DS/lib/src/domain/model/search_dto.dart
MODEL=$DS/lib/src/domain/model/search_results.dart
REPO_=$DS/lib/src/domain/repository/discovery_search_repository.dart
MODULE=$DS/lib/src/di/di_module.dart
SCOPE=$DS/lib/src/di/flow_scope.dart
PAGE=$DS/lib/src/presentation/page/discovery_search_page.dart
RESULTS=$DS/lib/src/presentation/widget/search_results_view.dart
TILE=$DS/lib/src/presentation/widget/search_result_tile.dart
HISTORY=$DS/lib/src/presentation/widget/search_history_view.dart
FAIL_MSG=$DS/lib/src/presentation/widget/failure_message.dart
DE=$DS/lib/src/l10n/discovery_search_de.arb
BARREL=$DS/lib/discovery_search.dart
NAV=$DW/lib/src/navigators/discovery_search_navigator_impl.dart
ROUTE=$DW/lib/src/routes/search_routes.dart
LOC=$AC/lib/src/locations/app_locations.dart
DOMAINS=$AC/lib/src/media/app_media.dart
HOME_ROUTES=app/mini_client/lib/src/router/app_routes.dart
FLOW_W=$DS/lib/src/flow/discovery_search_flow.dart
DQ=utility/mc_paging/lib/src/query/debounced_query.dart
DQ_TEST=//utility/mc_paging:debounced_query_test

STEPS=utility/mc_test_steps/lib/src
RO=$STEPS/environment/the_app_can_no_longer_write_to_storage.dart
SIO=$STEPS/storage_io.dart
STATE=$DS/lib/src/presentation/bloc/discovery_search_state.dart
FILES=($BLOC $MAP $DTO $MODEL $REPO_ $MODULE $SCOPE $PAGE $RESULTS $TILE $HISTORY $FAIL_MSG $DE $BARREL $NAV $ROUTE $LOC $DOMAINS $HOME_ROUTES $FLOW_W $DQ $RO $SIO $STATE)
for f in "${FILES[@]}"; do
  if ! git diff --quiet -- "$f" || ! git diff --cached --quiet -- "$f"; then
    say "REFUSING TO RUN: $f has uncommitted edits (commit them first)"
    exit 2
  fi
done
restore_all() { git checkout -- "${FILES[@]}"; }
trap restore_all EXIT

# run <targets...>: the test output, one line per test, plus Bazel's summary.
run() { bz test --nocache_test_results --test_output=all "$@" 2>&1 | tr '\r' '\n'; }

base="$(run $BDD $FLOW $ARCH $CONTRACT $GOLDEN $ROUTES $APP $BOOT $DQ_TEST)"
if grep -q -E "FAILED|NO STATUS|^ERROR" <<< "$base"; then
  say "BASELINE FAILS"; grep -E "FAILED|^ERROR" <<< "$base" | tee -a "$LOG"; exit 1
fi
say "baseline: PASS (9 targets)"

rc=0
n=0
killed=0
# mutate <id> <description> <file> <python expression on s> <targets...>
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
  if [[ "$file" == *.dart ]] && ! fvm dart format "$file" > /dev/null; then
    say "$id $what: FORMAT FAILED (not evidence)"; rc=1; git checkout -- "$file"; return
  fi
  local out; out="$(run "$@")"
  local first; first="$(grep -a -m1 -E '^  FAIL  |^[0-9:]+ \+[0-9]+ -[0-9]+: ' <<< "$out" | sed 's/^ *//')"
  if [[ -n "$first" ]]; then
    say "$id $what: KILLED ($first)"; killed=$((killed + 1))
  elif grep -q -a -E "^ERROR|FAILED TO BUILD|Build did NOT complete" <<< "$out"; then
    say "$id $what: COMPILE ERROR (not evidence)"; rc=1
  elif grep -q -a -E " FAILED in |NO STATUS" <<< "$out"; then
    # A target failed, but no test in it did (a crash, a format check).
    say "$id $what: TARGET FAILED WITHOUT A FAILING TEST (not evidence)"; rc=1
  elif ! grep -q -a -E " PASSED in " <<< "$out"; then
    say "$id $what: NO TEST RAN (not evidence)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}

# --- a sample of the engineer's mutations (re-run) ---
mutate AC1-a "hits of a group in reverse order" $MAP \
  "s.replace('for (final result in results)', 'for (final result in results.reversed)')" $BDD
mutate AC2-d "a double Retry sends two requests (the state check comes too late)" $BLOC \
  "s.replace('        if (state case _Failure(:final query)) {\n          await _search(query, emit);', '        if (state case _Failure(:final query)) {\n          await Future<void>.delayed(Duration.zero);\n          await _search(query, emit);')" $BDD
mutate AC3-d "the wiring replaces the search instead of pushing" $NAV \
  "s.replace('unawaited(_routerRef.router.push(AppLocations.comic(id.value)));', '_routerRef.router.go(AppLocations.comic(id.value));')" $ROUTES $APP
mutate AC5-b "a flow opened with a query does not search it" $BLOC \
  "s.replace('      _query.submit(query);', '      _query.submit(query.substring(0, 0));', 1)" $BDD $FLOW
mutate AC6-c "a stale answer is shown (no generation check)" $BLOC \
  "s.replace('    if (generation != _generation) {', '    if (generation != _generation && generation < 0) {')" $BDD
mutate AC6-d "clearing the field does not drop the answer in flight" $BLOC \
  "s.replace('      case _Cleared():\n        _generation++;\n', '      case _Cleared():\n')" $BDD
mutate AC6-f "a too-short query does not drop the answer in flight" $BLOC \
  "s.replace('    final generation = ++_generation;\n    if (query.runes.length < minQueryLength) {\n      _showHistory(emit);\n      return;\n    }\n', '    if (query.runes.length < minQueryLength) {\n      _showHistory(emit);\n      return;\n    }\n    final generation = ++_generation;\n')" $BDD
mutate AC6-j "a save that finishes after a clear is shown (no version check)" $BLOC \
  "s.replace('    if (version == _historyVersion) {\n      _recent = list;', '    if (version > 0) {\n      _recent = list;')" $BDD
mutate AC6-l "a tapped recent search waits for the debounce" $BLOC \
  "s.replace('        _query.submit(text);', '        _query.update(text);')" $BDD
mutate AC6-m "a failed save keeps the in-memory list instead of reading the stored one" $BLOC \
  "s.replace('(await _history.load()).getOrElse(() => const [])', '_recent')" $BDD
mutate R3-c "submit searches the last query again" $DQ \
  "s.replace('    if (query == _searched) {\n      return;\n    }\n    _searched = query;\n    onSearch(query);', '    _searched = query;\n    onSearch(query);')" $DQ_TEST
mutate R5-b "the backend's too-short answer is a failure (bloc)" $BLOC \
  "s.replace('          // The backend counts the query as too short (after folding).\n          _showHistory(emit);', '          // The backend counts the query as too short (after folding).\n          emit(\n            DiscoverySearchState.failure(\n              query: query,\n              error: const ApiFailure.clientError(400),\n            ),\n          );')" $BDD
mutate R7-a "a failed Clear is taken as done" $BLOC \
  "s.replace('final failed = cleared.fold((_) => false, (_) => true);', 'final failed = cleared.fold((_) => false, (_) => false);')" $BDD
mutate R8-a "a double tap opens twice (no guard)" $BLOC \
  "s.replace('        if (_openGuard?.isActive ?? false) {', '        if ((_openGuard?.isActive ?? false) && hit.title.isEmpty) {')" $BDD
mutate R10 "a blank linked query is kept (no keyboard)" $FLOW_W \
  "s.replace('return query == null || query.trim().isEmpty ? null : query;', 'return query;')" $BDD
# --- the Verifier's own mutations (V) ----------------------------------------
mutate V01 "the initial history read has no version check" $BLOC \
  "s.replace('        if (version == _historyVersion) {\n          _recent = loaded.getOrElse', '        if (version >= 0) {\n          _recent = loaded.getOrElse')" $BDD
mutate V02 "a failed Clear restores the list even after a later save" $BLOC \
  "s.replace('if (failed && version == _historyVersion) {', 'if (failed) {')" $BDD
mutate V03 "Clear empties the list only after storage answered" $BLOC \
  "s.replace('        _recent = const [];\n        _refreshHistory(emit);\n        final cleared = await _history.clear();', '        final cleared = await _history.clear();\n        _recent = const [];\n        _refreshHistory(emit);')" $BDD
mutate V05 "Retry searches another query (upper-cased)" $BLOC \
  "s.replace('        if (state case _Failure(:final query)) {\n          await _search(query, emit);', '        if (state case _Failure(:final query)) {\n          await _search(query.toUpperCase(), emit);')" $BDD
mutate V10 "any 400 with an error code is taken as too short" $REPO_ \
  "s.replace(\"(body['error'] as Map)['code'] == queryTooShortCode;\", \"(body['error'] as Map)['code'] != null;\")" $CONTRACT $BDD
mutate V11 "the open guard lasts 1 ms" $BLOC \
  "s.replace('const Duration openGuard = Duration(milliseconds: 500);', 'const Duration openGuard = Duration(milliseconds: 1);')" $BDD
mutate V11b "the open guard lasts 501 ms" $BLOC \
  "s.replace('const Duration openGuard = Duration(milliseconds: 500);', 'const Duration openGuard = Duration(milliseconds: 501);')" $BDD
mutate V14 "a blank submit clears but keeps the last query as searched" $DQ \
  "s[:s.index('void submit(')] + s[s.index('void submit('):].replace('        _searched = null;\n        onClear();', '        onClear();', 1)" $DQ_TEST
mutate V18 "the field always autofocuses" $PAGE \
  "s.replace('autofocus: widget.initialQuery == null,', 'autofocus: true,')" $BDD
mutate V19 "a tapped recent search is not put in the field" $PAGE \
  "s.replace('      text: query,\n      selection: TextSelection.collapsed(offset: query.length),', '      text: _controller.text,\n      selection: TextSelection.collapsed(offset: _controller.text.length),')" $BDD
mutate V26 "the flow is not keyed by its query" $FLOW_W \
  "s.replace('    key: ValueKey(_query),\n', '')" $FLOW $BDD
mutate V27 "a failure state is not reported to monitoring" $STATE \
  "s.replace('  @Implements<McFailureState>()\n', '')" $BDD $FLOW $CONTRACT $GOLDEN
mutate V27b "the backend's too-short answer reports an error" $BLOC \
  "s.replace('          // The backend counts the query as too short (after folding).\n          _showHistory(emit);', '          // The backend counts the query as too short (after folding).\n          _showHistory(emit);\n          addError(StateError(\'probe\'));')" $BDD
mutate V30 "a 301 ms debounce" $BLOC \
  "s.replace('const Duration searchDebounce = Duration(milliseconds: 300);', 'const Duration searchDebounce = Duration(milliseconds: 301);')" $BDD
mutate V31 "a keystroke does not cancel the pending search" $DQ \
  "s.replace('  void update(String text) {\n    if (_disposed) {\n      return;\n    }\n    _timer?.cancel();\n    _timer = null;\n', '  void update(String text) {\n    if (_disposed) {\n      return;\n    }\n', 1)" $BDD $DQ_TEST
mutate V32 "the read-only step leaves storage writable" $RO \
  "s.replace(\"  _chmod('555', readOnly);\n\", '')" $BDD
mutate V32b "the read-only step loses what was stored (reads fail too)" $RO \
  "s.replace('        entry.copySync(', '        if (entry.path.isEmpty) entry.copySync(')" $BDD
mutate V34 "storage I/O stops after the 10 fixed rounds" $SIO \
  "s.replace('for (var round = 0; unchanged < 25; round++) {', 'for (var round = 0; unchanged < 0; round++) {')" $BDD
mutate V35 "a search does not show that it is searching" $BLOC \
  "s.replace('    emit(DiscoverySearchState.searching(query: query));\n', '')" $BDD
mutate V40 "the wiring sends a character to the comic location" $NAV \
  "s.replace('AppLocations.character(id.value)', 'AppLocations.comic(id.value)')" $ROUTES $APP

say ""
say "$killed of $n mutations killed by a failing test"
exit $rc
