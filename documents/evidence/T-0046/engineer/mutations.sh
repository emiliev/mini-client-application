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

FILES=($BLOC $MAP $DTO $MODEL $REPO_ $MODULE $SCOPE $PAGE $RESULTS $TILE $HISTORY $FAIL_MSG $DE $BARREL $NAV $ROUTE $LOC $DOMAINS $HOME_ROUTES)
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

base="$(run $BDD $FLOW $ARCH $CONTRACT $GOLDEN $ROUTES $APP $BOOT)"
if grep -q -E "FAILED|NO STATUS|^ERROR" <<< "$base"; then
  say "BASELINE FAILS"; grep -E "FAILED|^ERROR" <<< "$base" | tee -a "$LOG"; exit 1
fi
say "baseline: PASS (8 targets)"

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

# --- AC1: grouped results in the backend's ranking, with title and art ----
mutate AC1-a "hits of a group in reverse order" $MAP \
  "s.replace('for (final result in results)', 'for (final result in results.reversed)')" $BDD
mutate AC1-b "groups in reverse order (comics first)" $MAP \
  "s.replace('groups: [for (final group in groups) group.toDomain()]', 'groups: [for (final group in groups.reversed) group.toDomain()]')" $BDD
mutate AC1-c "All shows 4 per group" $RESULTS \
  "s.replace('const int allFilterPreviewCount = 5;', 'const int allFilterPreviewCount = 4;')" $BDD
mutate AC1-d "the subtitle shows the title" $TILE \
  "s.replace('subtitle: subtitle == null ? null : Text(subtitle),', 'subtitle: subtitle == null ? null : Text(hit.title),')" $BDD
mutate AC1-e "every result gets the same art" $MAP \
  "s.replace('ApiImage(path: path,', \"ApiImage(path: 'mock-asset://characters/000',\")" $BDD
mutate AC1-f "the page size is not asked for" $REPO_ \
  "s.replace('_api.search(query, limit: searchPageSize)', '_api.search(query)')" $BDD
mutate AC1-g "See all does nothing" $RESULTS \
  "re.sub(r'onAction: more\s*\? \(\) => bloc\.add\(\s*DiscoverySearchEvent\.filterChanged\(\s*SearchFilter\.only\(group\.type\),\s*\),\s*\)', 'onAction: more ? () {}', s)" $BDD
mutate AC1-h "the chosen chip resets for the next query" $BLOC \
  "s.replace('                  filter: _filter,', '                  filter: SearchFilter.all,')" $BDD
mutate AC1-i "the Characters chip shows comics" $MODEL \
  "s.replace('characters => type == SearchType.character,', 'characters => type == SearchType.comic,')" $BDD
# --- AC2: failure with Retry, nothing found, too short --------------------
mutate AC2-a "a 1-character query is searched" $BLOC \
  "s.replace('const int minQueryLength = 2;', 'const int minQueryLength = 1;')" $BDD
mutate AC2-b "nothing found shows empty sections, not the empty state" $BLOC \
  "s.replace('          results.isEmpty\n', '          false\n')" $BDD
mutate AC2-c "Retry does nothing" $PAGE \
  "re.sub(r'onRetry: \(\) => context\.read<DiscoverySearchBloc>\(\)\.add\(\s*const DiscoverySearchEvent\.retry\(\),\s*\)', 'onRetry: () {}', s)" $BDD
mutate AC2-d "a double Retry sends two requests (the state check comes too late)" $BLOC \
  "s.replace('        if (state case _Failure(:final query)) {\n          await _search(query, emit);', '        if (state case _Failure(:final query)) {\n          await Future<void>.delayed(Duration.zero);\n          await _search(query, emit);')" $BDD
mutate AC2-e "a server failure reads as a generic one" $FAIL_MSG \
  "s.replace('ApiServer() => core.errorServer,', '')" $BDD
# --- AC3: results leave through the navigator ------------------------------
mutate AC3-a "a character result carries the wrong id" $MAP \
  "s.replace('id: CharacterId(id),', 'id: CharacterId(id + 1),')" $BDD
mutate AC3-b "openComic twice" $BLOC \
  "s.replace('_navigator.openComic(id);', '_navigator..openComic(id)..openComic(id);')" $BDD
mutate AC3-c "the wiring sends a comic to the character location" $NAV \
  "s.replace('AppLocations.comic(id.value)', 'AppLocations.character(id.value)')" $ROUTES $APP
mutate AC3-d "the wiring replaces the search instead of pushing" $NAV \
  "s.replace('unawaited(_routerRef.router.push(AppLocations.comic(id.value)));', '_routerRef.router.go(AppLocations.comic(id.value));')" $ROUTES $APP
# --- AC4: German and the pseudo-locale --------------------------------------
mutate AC4-a "German nothing-found title left in English" $DE \
  "s.replace('\"Keine Treffer\"', '\"No results\"')" $BDD
mutate AC4-b "the All chip is not localised" $RESULTS \
  "s.replace('label: l10n.discoverySearchFilterAll,', \"label: 'All',\")" $BDD
mutate AC4-c "the no-history hint cannot wrap (overflows)" $HISTORY \
  "s.replace('        child: Text(\n          l10n.discoverySearchNoRecent,', '        child: Row(children: [Text(\n          l10n.discoverySearchNoRecent,', 1).replace('              .copyWith(color: context.mcPalette.onSurfaceMuted),\n        ),', '              .copyWith(color: context.mcPalette.onSurfaceMuted),\n        )]),', 1)" $BDD
# --- AC5: route, link, home entry -------------------------------------------
mutate AC5-a "the route drops the query" $ROUTE \
  "s.replace('search(query: q)', 'search()')" $ROUTES
mutate AC5-b "a flow opened with a query does not search it" $BLOC \
  "s.replace('      _query.update(query);', '      _query.update(query.substring(0, 0));', 1)" $BDD $FLOW
mutate AC5-c "AppLocations.search does not encode the query" $LOC \
  "s.replace(\"Uri(\n    path: '/search',\n    queryParameters: query == null ? null : {'q': query},\n  ).toString();\", \"query == null ? '/search' : '/search?q=\$query';\")" $ROUTES $BOOT
mutate AC5-d "Search on home opens the characters" $HOME_ROUTES \
  "s.replace('context.push(AppLocations.search())', 'context.push(AppLocations.characters)')" $APP
mutate AC5-e "the app's backend has no discovery domain" $DOMAINS \
  "s.replace('  DiscoveryMockDomain(),\n', '')" $APP $BOOT
# --- AC6: debounce, latest query wins, history ------------------------------
mutate AC6-a "no debounce" $BLOC \
  "s.replace('delay: searchDebounce,', 'delay: Duration.zero,')" $BDD
mutate AC6-b "a 200 ms debounce" $BLOC \
  "s.replace('const Duration searchDebounce = Duration(milliseconds: 300);', 'const Duration searchDebounce = Duration(milliseconds: 200);')" $BDD
mutate AC6-c "a stale answer is shown (no generation check)" $BLOC \
  "s.replace('    if (generation != _generation) {', '    if (generation != _generation && generation < 0) {')" $BDD
mutate AC6-d "clearing the field does not drop the answer in flight" $BLOC \
  "s.replace('      case _Cleared():\n        _generation++;\n', '      case _Cleared():\n')" $BDD
mutate AC6-e "clearing the field keeps the previous state" $BLOC \
  "s.replace('      case _Cleared():\n        _generation++;\n        _showHistory(emit);\n', '      case _Cleared():\n        _generation++;\n')" $BDD
mutate AC6-f "a too-short query does not drop the answer in flight" $BLOC \
  "s.replace('    final generation = ++_generation;\n    if (query.runes.length < minQueryLength) {\n      _showHistory(emit);\n      return;\n    }\n', '    if (query.runes.length < minQueryLength) {\n      _showHistory(emit);\n      return;\n    }\n    final generation = ++_generation;\n')" $BDD
mutate AC6-g "a chip sends a new request" $BLOC \
  "s.replace('          emit(shown.copyWith(filter: filter));\n', '          emit(shown.copyWith(filter: filter));\n          await _search(shown.query, emit);\n')" $BDD
mutate AC6-h "nothing is saved" $BLOC \
  "s.replace('      await _remember(query, emit);\n', '')" $BDD
mutate AC6-i "a search that found nothing is saved too" $BLOC \
  "s.replace('        return !results.isEmpty;', '        return true;')" $BDD
mutate AC6-j "a save that finishes after a clear is shown (no version check)" $BLOC \
  "s.replace('    final saved = await _history.add(query);\n    if (version == _historyVersion) {', '    final saved = await _history.add(query);\n    if (version > 0) {')" $BDD
mutate AC6-k "Clear does not clear the storage" $BLOC \
  "s.replace('        await _history.clear();\n', '')" $BDD
mutate AC6-l "a recent search tapped is put in the field but not searched" $PAGE \
  "s.replace('    _changed(query);\n', '')" $BDD
mutate AC6-m "a failed save empties the list" $BLOC \
  "s.replace('      }, (_) {});', '      }, (_) => _recent = const []);')" $BDD
mutate AC6-n "11 recent searches are kept" $MODULE \
  "s.replace('const int searchHistoryCap = 10;', 'const int searchHistoryCap = 11;')" $BDD
mutate AC6-o "each flow has its own history key (not remembered)" $MODULE \
  "s.replace('key: searchHistoryKey)', \"key: '\$searchHistoryKey.\${DateTime.now().microsecondsSinceEpoch}')\")" $BDD
# --- AC7: the barrel, the root imports, the wire shape ----------------------
mutate AC7-a "barrel exports a page" $BARREL \
  "s + \"export 'package:discovery_search/src/presentation/page/discovery_search_page.dart' show DiscoverySearchPage;\n\"" $ARCH
mutate AC7-b "FileStore not forwarded" $SCOPE \
  "s.replace('  RootImport<FileStore>(),\n', '')" $FLOW
mutate AC7-c "a missing subtitle is written as null" $DTO \
  "s.replace('@JsonSerializable(explicitToJson: true, includeIfNull: false)', '@JsonSerializable(explicitToJson: true)')" $CONTRACT
mutate AC7-d "a result in the wrong group is accepted" $MAP \
  "s.replace('result.type == groupType.wireName', 'result.type.isNotEmpty')" $CONTRACT
# --- goldens -----------------------------------------------------------------
mutate GOLD-a "result art 40 px wide" $TILE \
  "s.replace('const double searchResultArtWidth = 36;', 'const double searchResultArtWidth = 40;')" $GOLDEN

say ""
say "$killed of $n mutations killed by a failing test"
cp "$LOG" "documents/evidence/$MC_TASK/$MC_ROLE/mutations.log" 2>/dev/null || true
exit $rc
