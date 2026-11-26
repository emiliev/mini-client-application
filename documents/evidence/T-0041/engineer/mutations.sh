#!/bin/bash
# T-0041 mutation check: one or more mutations per AC behaviour. Each must
# make a named test target FAIL with a failing test (a mutation that
# survives, or that only breaks the build, proves nothing). The unmutated
# tree must pass first (positive control). Each mutation is restored with
# `git checkout` of its file and the restore is verified; the script REFUSES
# to run when a file it mutates has uncommitted edits.
#
#   MC_TASK=T-0041 MC_ROLE=engineer documents/evidence/T-0041/engineer/mutations.sh
#
# Output base /tmp/mc-ob-$MC_TASK-$MC_ROLE; log /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log
# (also printed). Exit 0 only if every mutation was applied and killed.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${MC_TASK:?set MC_TASK (e.g. T-0041)}"
: "${MC_ROLE:?set MC_ROLE (engineer or verifier)}"
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
LOG="/tmp/mc-$MC_TASK-$MC_ROLE-mutations.log"
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

CD=feature/comics/comics_details
CL=feature/characters/characters_list
PW=app/wiring/publishing_wiring
UW=app/wiring/universe_wiring
BDD=//$CD:bdd_test
FLOW=//$CD:flow_scope_test
ARCH=//$CD:architecture_test
ROUTES=//$PW:routes_test
CL_BDD=//$CL:bdd_test
UW_ROUTES=//$UW:routes_test
APP=//app/mini_client:comic_route_test

FILES=(
  $CD/lib/comics_details.dart
  $CD/lib/src/di/flow_scope.dart
  $CD/lib/src/domain/model/comic_mapper.dart
  $CD/lib/src/domain/repository/comics_details_repository.dart
  $CD/lib/src/l10n/comics_details_de.arb
  $CD/lib/src/presentation/bloc/comic_details_bloc.dart
  $CD/lib/src/presentation/bloc/comic_favourite_bloc.dart
  $CD/lib/src/presentation/page/comic_details_page.dart
  $CD/lib/src/presentation/widget/comic_facts.dart
  $CD/lib/src/presentation/widget/comic_header.dart
  $CD/lib/src/presentation/widget/favourite_toggle.dart
  $CL/lib/src/presentation/bloc/related_comics_bloc.dart
  $PW/lib/src/navigators/comics_details_navigator_impl.dart
  $PW/lib/src/routes/comics_routes.dart
  $PW/lib/src/sign_in/fixture_sign_in_sheet.dart
  $UW/lib/src/navigators/characters_list_navigator_impl.dart
)
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

base="$(run $BDD $FLOW $ARCH $ROUTES $CL_BDD $UW_ROUTES $APP)"
if grep -q -E "FAILED|NO STATUS|^ERROR" <<< "$base"; then
  say "BASELINE FAILS"; grep -E "FAILED|^ERROR" <<< "$base" | tee -a "$LOG"; exit 1
fi
say "baseline: PASS (7 targets)"

rc=0
n=0
killed=0
# mutate <id> <description> <file> <python expression on s> <targets...>
mutate() {
  local id="$1" what="$2" file="$3" expr="$4"; shift 4
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

MAP=$CD/lib/src/domain/model/comic_mapper.dart
REPO_=$CD/lib/src/domain/repository/comics_details_repository.dart
DET=$CD/lib/src/presentation/bloc/comic_details_bloc.dart
FAV=$CD/lib/src/presentation/bloc/comic_favourite_bloc.dart
PAGE=$CD/lib/src/presentation/page/comic_details_page.dart
FACTS=$CD/lib/src/presentation/widget/comic_facts.dart
HEAD=$CD/lib/src/presentation/widget/comic_header.dart
TOGGLE=$CD/lib/src/presentation/widget/favourite_toggle.dart
NAV=$PW/lib/src/navigators/comics_details_navigator_impl.dart
SHEET=$PW/lib/src/sign_in/fixture_sign_in_sheet.dart

# --- AC1: the comic, its facts, credits and cast -------------------------
mutate AC1-a "price shown as raw minor units" $FACTS \
  "s.replace('formatMoney(comic.price, locale)', \"'\${comic.price.minorUnits}'\")" $BDD
mutate AC1-b "cast in reverse order" $REPO_ \
  "s.replace('cast: [...cast.nonNulls]', 'cast: [...cast.nonNulls.toList().reversed]')" $BDD
mutate AC1-c "last credit dropped" $MAP \
  "s.replace('for (final credit in creators)', 'for (final credit in creators.take(creators.length - 1))')" $BDD
mutate AC1-d "synopsis shows the title" $PAGE \
  "s.replace('comic.description,', 'comic.title,')" $BDD
mutate AC1-e "issue number off by one in the header" $HEAD \
  "s.replace('l10n.comicsDetailsIssue(comic.issueNumber)', 'l10n.comicsDetailsIssue(comic.issueNumber + 1)')" $BDD
# --- AC2: failure with Retry, not found ----------------------------------
mutate AC2-a "unknown comic shown as a failure" $DET \
  "s.replace('failure is ApiNotFound', 'failure is ApiClientError')" $BDD
mutate AC2-b "Retry does nothing" $PAGE \
  "re.sub(r'onRetry: \(\) => context\.read<ComicDetailsBloc>\(\)\.add\(\s*const ComicDetailsEvent\.load\(\),\s*\)', 'onRetry: () {}', s)" $BDD
mutate AC2-c "a missing cast member fails the comic" $REPO_ \
  "s.replace('statusCode == 404', 'statusCode == 499')" $BDD
# --- AC3: the cast and the credits leave through the navigator ------------
mutate AC3-a "openCharacter with the wrong id" $DET \
  "s.replace('_navigator.openCharacter(id);', '_navigator.openCharacter(CharacterId(id.value + 1));')" $BDD
mutate AC3-b "openCreator twice" $DET \
  "s.replace('_navigator.openCreator(id);', '_navigator..openCreator(id)..openCreator(id);')" $BDD
mutate AC3-c "the wiring sends a character to the comic location" $NAV \
  "s.replace('AppLocations.character(id.value)', 'AppLocations.comic(id.value)')" $ROUTES $APP
# --- AC4: German and the pseudo-locale ------------------------------------
mutate AC4-a "dates and prices always in English" $FACTS \
  "s.replace('Localizations.localeOf(context).toString()', \"'en'\")" $BDD
mutate AC4-b "German favourite label left in English" $CD/lib/src/l10n/comics_details_de.arb \
  "s.replace('\"Zu Favoriten hinzufügen\"', '\"Add to favourites\"')" $BDD
mutate AC4-c "header text column not flexible (overflows)" $HEAD \
  "s.replace('          Expanded(\n            child: Column(', '          SizedBox(\n            width: 400,\n            child: Column(', 1)" $BDD
# --- AC5: the route, the deep link and the preview's link -----------------
mutate AC5-a "comic route path drifts from AppLocations" $PW/lib/src/routes/comics_routes.dart \
  "s.replace(\"path: '/comics/:id'\", \"path: '/comic/:id'\")" $ROUTES $APP
mutate AC5-b "openComic pushes the character location" $UW/lib/src/navigators/characters_list_navigator_impl.dart \
  "s.replace('AppLocations.comic(id.value)', 'AppLocations.character(id.value)')" $UW_ROUTES $APP
mutate AC5-c "a related comic opens the wrong id" $CL/lib/src/presentation/bloc/related_comics_bloc.dart \
  "s.replace('_navigator.openComic(id);', '_navigator.openComic(ComicId(id.value + 1));')" $CL_BDD
# --- AC6: the favourite and sign-in ----------------------------------------
mutate AC6-a "signed out, no sign-in asked" $FAV \
  "s.replace('    if (!_session.isSignedIn) {\n      emit(ComicFavouriteState.ready(favourite: current, saving: true));', \"    if (_session.userId == 'nobody') {\n      emit(ComicFavouriteState.ready(favourite: current, saving: true));\")" $BDD
mutate AC6-b "a cancelled sign-in still writes" $FAV \
  "s.replace('        emit(ComicFavouriteState.ready(favourite: current));\n        return;\n', '        emit(ComicFavouriteState.ready(favourite: current));\n')" $BDD
mutate AC6-c "DataChanged published twice" $FAV \
  "s.replace('_bus.publish(const DataChanged(favouritesTopic));', '_bus..publish(const DataChanged(favouritesTopic))..publish(const DataChanged(favouritesTopic));')" $BDD
mutate AC6-d "no rollback after a failed write" $FAV \
  "s.replace('ComicFavouriteState.saveFailed(error, favourite: current)', 'ComicFavouriteState.saveFailed(error, favourite: wanted)')" $BDD
mutate AC6-e "no guard against a second tap" $FAV \
  "s.replace('if (_busy || state is _Loading) {', 'if (state is _Loading) {')" $BDD
mutate AC6-f "not optimistic" $FAV \
  "s.replace('emit(ComicFavouriteState.ready(favourite: wanted, saving: true));', 'emit(ComicFavouriteState.ready(favourite: current, saving: true));')" $BDD
mutate AC6-g "no inline error after a failed write" $TOGGLE \
  "s.replace('            l10n.comicsDetailsFavouriteSaveFailed,', '            null,')" $BDD
mutate AC6-h "the wiring answers true without the sheet" $NAV \
  "s.replace('return showFixtureSignInSheet(context, _auth);', 'return true;')" $ROUTES
mutate AC6-i "the sheet answers true when signing in failed" $SHEET \
  "s.replace('if (result.getOrNull() != null) {', 'if (result.getOrNull() != null || mounted) {')" $ROUTES
# --- AC7: the barrel and the root imports ----------------------------------
mutate AC7-a "barrel exports a page" $CD/lib/comics_details.dart \
  "s + \"export 'package:comics_details/src/presentation/page/comic_details_page.dart' show ComicDetailsPage;\n\"" $ARCH
mutate AC7-b "SessionReader not forwarded (Session instead)" $CD/lib/src/di/flow_scope.dart \
  "s.replace('  RootImport<SessionReader>(),', '  RootImport<Session>(),')" $FLOW

say ""
say "$killed of $n mutations killed by a failing test"
cp "$LOG" "documents/evidence/$MC_TASK/$MC_ROLE/mutations.log" 2>/dev/null || true
exit $rc
