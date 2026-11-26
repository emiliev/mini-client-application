#!/bin/bash
# T-0047 engineer mutation checks: each mutation of the discovery package must
# turn at least one test red (a mutation that survives, or that fails to
# build, fails this script). Every validation rule, the auth check, ownership and each write are pinned one by one.
#
#   MC_TASK=T-0047 MC_ROLE=engineer documents/evidence/T-0047/engineer/mutations.sh
#
# Run from a clean, committed tree: every mutation is undone with
# `git checkout -- <package>`, which would also discard uncommitted edits.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
: "${MC_TASK:?set MC_TASK, e.g. T-0047}"
: "${MC_ROLE:?set MC_ROLE, e.g. engineer}"
if [[ -n "$(git status --porcelain utility/mc_fixtures_library)" ]]; then
  echo "refusing to run: utility/mc_fixtures_library has uncommitted changes" >&2
  exit 2
fi
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
P=utility/mc_fixtures_library
H=$P/lib/src/handlers/library_handlers.dart
DOM=$P/lib/src/domain.dart
RL=$P/lib/src/data/reading_list.dart
LOG="$(mktemp -t "mc-$MC_TASK-$MC_ROLE-mut.XXXXXX")"
trap 'git checkout -- "$P"; rm -f "$LOG"' EXIT
killed=0
survived=0
broken=0

run_tests() {
  tool/bazelw --output_base="$OB" test //$P/... > "$LOG" 2>&1
}

# mutate <name> <file> <old> <new>
mutate() {
  local name="$1" file="$2" old="$3" new="$4"
  echo "=== $name"
  if ! python3 -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if old not in s:
    sys.exit("pattern not found: " + old)
open(p, "w").write(s.replace(old, new, 1))
' "$file" "$old" "$new"; then
    echo "    PATTERN NOT FOUND"; broken=$((broken + 1)); git checkout -- "$P"; return
  fi
  run_tests
  local failed
  failed="$(tr '\r' '\n' < "$LOG" | grep -aE '^//.*FAILED' | sed 's/ *FAILED.*//' | tr '\n' ' ')"
  if [[ -n "$failed" ]]; then
    echo "    KILLED by: $failed"
    killed=$((killed + 1))
  elif tr '\r' '\n' < "$LOG" | grep -aq 'Build did NOT complete'; then
    echo "    BUILD ERROR (does not count as killed)"
    tr '\r' '\n' < "$LOG" | grep -aE 'error|info -|warning' | head -3
    broken=$((broken + 1))
  else
    echo "    SURVIVED"; survived=$((survived + 1))
  fi
  git checkout -- "$P"
}

# Baseline: the unmutated tree must pass.
run_tests || { echo "BASELINE FAILS"; tr '\r' '\n' < "$LOG" | tail -20; exit 1; }
echo "baseline PASS"

# --- validation: name --------------------------------------------------
mutate "V1 empty name accepted" $H "length < nameMinLength ||" "length < 0 ||"
mutate "V2 name limit off by one" $H "length > nameMaxLength)" "length > nameMaxLength + 1)"
mutate "V3 name not trimmed before measuring" $H "raw.trim().runes.length" "raw.runes.length"
mutate "V4 name measured in UTF-16 units" $H "raw.trim().runes.length" "raw.trim().length"
mutate "V5 created name stored untrimmed" $H "name: (body['name'] as String).trim()," "name: body['name'] as String,"
mutate "V6 updated name stored untrimmed" $H "..name = (body['name'] as String).trim()" "..name = body['name'] as String"
mutate "V7 non-string name accepted" $H "raw is String ? raw.trim().runes.length : -1" "raw is String ? raw.trim().runes.length : 1"
mutate "V8 name constant 61" $RL "const int nameMaxLength = 60;" "const int nameMaxLength = 61;"
# --- validation: description -------------------------------------------
mutate "V9 description limit exclusive" $H "raw.runes.length > descriptionMaxLength" "raw.runes.length >= descriptionMaxLength"
mutate "V10 description limit off by one" $H "raw.runes.length > descriptionMaxLength" "raw.runes.length > descriptionMaxLength + 1"
mutate "V11 description measured in UTF-16 units" $H "raw.runes.length > descriptionMaxLength" "raw.length > descriptionMaxLength"
mutate "V12 non-string description accepted" $H "(raw is! String || raw.runes.length > descriptionMaxLength)" "(raw is String && raw.runes.length > descriptionMaxLength)"
mutate "V13 description constant 281" $RL "const int descriptionMaxLength = 280;" "const int descriptionMaxLength = 281;"
mutate "V14 update keeps the old description when absent" $H "..description = body['description'] as String? ?? ''" "..description = (body['description'] as String?) ?? list.description"
# --- validation: visibility ---------------------------------------------
mutate "V15 any visibility accepted" $H "if (!visibilities.contains(raw)) {" "if (false) {"
mutate "V16 visibility case-insensitive" $H "if (!visibilities.contains(raw)) {" "if (!visibilities.contains(raw is String ? raw.toLowerCase() : raw)) {"
mutate "V17 update skips the visibility check" $H "_checkVisibility(body['visibility']);" "null;"
mutate "V18 update does not store visibility" $H "..visibility = body['visibility'] as String" "..visibility = list.visibility"
# --- validation: comicIds -----------------------------------------------
mutate "V19 comicIds shape unchecked" $H "if (raw is! List || raw.any((e) => e is! int)) {" "if (raw is! List) {"
mutate "V20 more than 100 allowed (limit 101)" $H "ids.length > maxComicsPerList" "ids.length > maxComicsPerList + 1"
mutate "V21 100 rejected" $H "ids.length > maxComicsPerList" "ids.length >= maxComicsPerList"
mutate "V22 duplicates allowed" $H "if (!seen.add(id)) {" "if (!seen.add(id) && false) {"
mutate "V23 unknown comics allowed" $H "if (universe.findComic(id) == null) {" "if (false) {"
mutate "V24 create skips the comicIds check" $H "_checkVisibility(body['visibility']) ??
          _checkComicIds(body['comicIds'], universe);" "_checkVisibility(body['visibility']);"
mutate "V25 items route skips the comicIds check" $H "final error = _checkComicIds(body['comicIds'], universe);" "const MockResponse? error = null;"
mutate "V26 max constant 101" $RL "const int maxComicsPerList = 100;" "const int maxComicsPerList = 101;"
mutate "V27 unknown ids are checked before duplicates" $H "final seen = <int>{};
  for (final id in ids) {
    if (!seen.add(id)) {" "final seen = <int>{};
  for (final id in ids.where((i) => universe.findComic(i) != null)) {
    if (!seen.add(id)) {"
# --- auth and ownership -------------------------------------------------
mutate "A1 no bearer needed (falls back to the first user)" $H "final user = userForAuthorization(request.headers['authorization']);" "final user = userForAuthorization(request.headers['authorization']) ?? fixtureUsers.first;"
mutate "A2 the Authorization header is never read" $H "request.headers['authorization']" "request.headers['x-authorization']"
mutate "A3 unauthenticated answers 403" $H "MockResponse _unauthenticated() => MockResponse.error(
  401," "MockResponse _unauthenticated() => MockResponse.error(
  403,"
mutate "A4 unauthenticated code changed" $H "'unauthenticated'," "'forbidden',"
mutate "A5 foreign list found (ownership ignored)" $H "for (final list in state.listsByUser[user]!) {" "for (final list in state.listsByUser.values.expand((l) => l)) {"
mutate "A6 foreign list answers 403" $H "MockResponse _notFound(String id) => MockResponse.error(
  404," "MockResponse _notFound(String id) => MockResponse.error(
  403,"
mutate "A7 listing returns every user's lists" $H "..._state(context, universe, seed: seed).listsByUser[user.id]!," "..._state(context, universe, seed: seed).listsByUser.values.expand((l) => l),"
mutate "A8 create files the list under the first user" $H "state.listsByUser[user.id]!.add(list);" "state.listsByUser['u-100']!.add(list);"
# --- CRUD ---------------------------------------------------------------
mutate "C1 create answers 200" $H "return MockResponse(201, _detail(list, universe));" "return MockResponse(200, _detail(list, universe));"
mutate "C2 delete does not delete" $H "state.listsByUser[user.id]!.remove(list);" "state.listsByUser[user.id]!.contains(list);"
mutate "C3 reorder sorts the ids" $H "..comicIds = [...(body['comicIds'] as List).cast<int>()]" "..comicIds = ([...(body['comicIds'] as List).cast<int>()]..sort())"
mutate "C4 create sorts the ids" $H "comicIds: [...(body['comicIds'] as List).cast<int>()]," "comicIds: ([...(body['comicIds'] as List).cast<int>()]..sort()),"
mutate "C5 listing oldest first" $H "b.updatedAt.compareTo(a.updatedAt)" "a.updatedAt.compareTo(b.updatedAt)"
mutate "C6 writes do not move updatedAt" $H "++state.ticks" "state.ticks"
mutate "C7 ids are reused" $H "id: 'l-\${state.nextNumber++}'," "id: 'l-\${state.nextNumber}',"
mutate "C8 writes do not persist (state rebuilt per request)" $H "if (existing != null) {" "if (false) {"
mutate "C9 an item shows another comic's title" $H "'title': universe.findComic(id)!.title," "'title': universe.byTitle.first.title,"
mutate "C10 an item shows another thumbnail" $H "'thumbnail': universe.findComic(id)!.cover.toJson()," "'thumbnail': universe.byTitle.first.cover.toJson(),"
mutate "C11 itemCount off by one" $RL "'itemCount': comicIds.length," "'itemCount': comicIds.length + 1,"
mutate "C12 update clears the items" $H "..visibility = body['visibility'] as String
        ..updatedAt = _touch(state, context);" "..visibility = body['visibility'] as String
        ..comicIds = <int>[]
        ..updatedAt = _touch(state, context);"
mutate "C13 seeded lists start without items" $H "comicIds: [for (final i in _seedItems[index]) universe.byTitle[i].id]," "comicIds: const [],"
# --- fixture sets and scenarios -----------------------------------------
mutate "S1 empty set seeded" $H "if (seed) {
    void make(" "if (true) {
    void make("
mutate "S2 empty scenario shares the default state" $H "final key = seed ? _stateKey : _emptyStateKey;" "final key = _stateKey;"
mutate "S3 server_error set body differs from the scenario" $H "'injected_failure',
      'Injected HTTP 500" "'server_error',
      'Injected HTTP 500"
mutate "S4 server_error set misses a route" $DOM "for (final route in libraryRouteManifest) route: handlers.serverError," "for (final route in libraryRouteManifest.skip(1)) route: handlers.serverError,"
mutate "S5 server_error scenario misses a route" $DOM "for (final route in libraryRouteManifest)
          FailureRule(" "for (final route in libraryRouteManifest.skip(1))
          FailureRule("
mutate "S6 empty set is seeded through the default handlers" $DOM "_handlers(ComicUniverse(environment.seed), seed: false)," "_handlers(ComicUniverse(environment.seed), seed: true),"
echo
echo "killed=$killed survived=$survived broken=$broken"
git status --short "$P"
[[ $survived -eq 0 && $broken -eq 0 ]]
