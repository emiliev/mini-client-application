#!/bin/bash
# T-0041 Verifier mutation run: my own mutations (V*) plus a re-run of 17 of
# the engineer's 43 (same ids). Each must make a named target FAIL with a
# failing test; a compile error or a survivor is reported. Each file is
# restored with `git checkout` and the restore is verified.
#   cd <worktree> && bash <this> [ids...]
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-aedf1b73f30091004
cd "$W"
OB=/tmp/mc-ob-T-0041-verifier
LOG=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0041-verifier/mutations.log
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }
[[ -z "$(git status --porcelain)" ]] || { say "REFUSING: tree not clean"; exit 2; }
ONLY=" $* "

CD=feature/comics/comics_details
CL=feature/characters/characters_list
PW=app/wiring/publishing_wiring
UW=app/wiring/universe_wiring
BDD=//$CD:bdd_test
ARCH=//$CD:architecture_test
ROUTES=//$PW:routes_test
CL_BDD=//$CL:bdd_test
UW_ROUTES=//$UW:routes_test
APP=//app/mini_client:comic_route_test
FIX=//utility/mc_fixtures_comics/...
ARCHCHECK=//tool/mc_arch_check:arch_check_test

run() { bz test --nocache_test_results --test_output=all "$@" 2>&1 | tr '\r' '\n'; }
n=0; killed=0; rc=0
mutate() {
  local id="$1" what="$2" file="$3" expr="$4"; shift 4
  if [[ "$ONLY" != "  " && "$ONLY" != *" $id "* ]]; then return; fi
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
    say "$id $what: COMPILE ERROR (not evidence)"; grep -a -m3 -E "^ERROR|rror:" <<< "$out" | tee -a "$LOG"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; exit 1; }
}

REPO_=$CD/lib/src/domain/repository/comics_details_repository.dart
MAP=$CD/lib/src/domain/model/comic_mapper.dart
DET=$CD/lib/src/presentation/bloc/comic_details_bloc.dart
FAV=$CD/lib/src/presentation/bloc/comic_favourite_bloc.dart
PAGE=$CD/lib/src/presentation/page/comic_details_page.dart
FACTS=$CD/lib/src/presentation/widget/comic_facts.dart
TOGGLE=$CD/lib/src/presentation/widget/favourite_toggle.dart
NAV=$PW/lib/src/navigators/comics_details_navigator_impl.dart
SHEET=$PW/lib/src/sign_in/fixture_sign_in_sheet.dart

# ---- my own (V) ----------------------------------------------------------
mutate V01 "the wrong comic is fetched (id - 1500)" $REPO_ \
  "s.replace('(await _api.getComic(id.value)).toDomain()', '(await _api.getComic(id.value - 1500)).toDomain()')" $BDD
mutate V02 "the Pages fact row is missing" $FACTS \
  "s.replace('      (l10n.comicsDetailsFactPages, formatNumber(comic.pageCount, locale)),\n', '')" $BDD
mutate V03 "dates always German" $FACTS \
  "s.replace('formatDate(comic.releaseDate, locale)', \"formatDate(comic.releaseDate, 'de')\")" $BDD
mutate V04 "German prices formatted as English" $FACTS \
  "s.replace('formatMoney(comic.price, locale)', \"formatMoney(comic.price, locale == 'de' ? 'en' : locale)\")" $BDD
mutate V05 "Retry opens the cover instead of reloading" $PAGE \
  "s.replace('              const ComicDetailsEvent.load(),', '              const ComicDetailsEvent.openCover(),')" $BDD
mutate V06 "an unknown id throws (crash)" $DET \
  "s.replace('? const ComicDetailsState.notFound()', \"? throw StateError('unknown comic')\")" $BDD
mutate V07 "a sign-out elsewhere is not applied" $FAV \
  "s.replace('if (!_busy && _session.epoch != _shownEpoch) {', 'if (!_busy && _session.epoch != _shownEpoch && _session.isSignedIn) {')" $BDD
mutate V08 "a sign-in elsewhere is not applied" $FAV \
  "s.replace('if (!_busy && _session.epoch != _shownEpoch) {', 'if (!_busy && _session.epoch != _shownEpoch && !_session.isSignedIn) {')" $BDD
mutate V09 "DataChanged published on a failed write too" $FAV \
  "s.replace('      (error) => emit(\n        ComicFavouriteState.saveFailed(error, favourite: current),\n      ),', '      (error) {\n        _bus.publish(const DataChanged(favouritesTopic));\n        emit(ComicFavouriteState.saveFailed(error, favourite: current));\n      },')" $BDD
mutate V10 "DataChanged published when no write was needed" $FAV \
  "s.replace('        emit(const ComicFavouriteState.ready(favourite: true));\n        return;', '        _bus.publish(const DataChanged(favouritesTopic));\n        emit(const ComicFavouriteState.ready(favourite: true));\n        return;')" $BDD
mutate V11 "a cancelled sign-in still reads the flag (a request)" $FAV \
  "s.replace('      if (!await _navigator.requestSignIn() || !_session.isSignedIn) {\n        _shownEpoch = _session.epoch;', '      if (!await _navigator.requestSignIn() || !_session.isSignedIn) {\n        await _repository.isFavourite(_comicId);\n        _shownEpoch = _session.epoch;')" $BDD
mutate V12 "the toggle is not marked saving (enabled during the write)" $FAV \
  "s.replace('emit(ComicFavouriteState.ready(favourite: wanted, saving: true));', 'emit(ComicFavouriteState.ready(favourite: wanted));')" $BDD
mutate V13 "the favourite flag is read for the wrong comic" $REPO_ \
  "s.replace('(await _api.getFavourite(id.value)).favourite', '(await _api.getFavourite(id.value + 1)).favourite')" $BDD
mutate V14 "Not now stays enabled while signing in" $SHEET \
  "s.replace('                onPressed: _busy\n                    ? null\n                    : () => Navigator.of(context).pop(false),', '                onPressed: () => Navigator.of(context).pop(false),')" $ROUTES
mutate V15 "the sheet shows even when signed in" $NAV \
  "s.replace('    if (_session.isSignedIn) {\n      return true;', \"    if (_session.isSignedIn && _session.userId == 'nobody') {\n      return true;\")" $ROUTES
mutate V16 "the route builds the wrong comic id" $PW/lib/src/routes/comics_routes.dart \
  "s.replace('comicDetails(id);', 'comicDetails(id + 1);')" $ROUTES $APP
mutate V17 "related comics ask for one too many" $CL/lib/src/domain/repository/characters_list_repository.dart \
  "s.replace('        limit: limit,\n', '        limit: limit + 1,\n')" $CL_BDD
mutate V18 "the fixture cast summary names drift from the characters domain" utility/mc_fixtures_comics/lib/src/data/universe.dart \
  "s.replace('return CharacterRef(id: c.id, name: c.name, thumbnail: c.thumbnail);', 'return CharacterRef(id: c.id, name: c.name.toUpperCase(), thumbnail: c.thumbnail);')" $FIX
mutate V19 "the cast member art ignored (cover used)" $MAP \
  "s.replace('    image: thumbnail.toDomain(),', '    image: const ApiImage(path: \'mock-asset://covers/000\', variant: ImageVariant.portraitMedium),')" $BDD
mutate V20 "the save error never shows (load error instead)" $TOGGLE \
  "s.replace('            l10n.comicsDetailsFavouriteSaveFailed,', '            l10n.comicsDetailsFavouriteLoadFailed,')" $BDD

# ---- engineer's, re-run (same ids and texts) -------------------------------
mutate AC1-b "cast in reverse order" $MAP \
  "s.replace('for (final member in characters)', 'for (final member in characters.reversed)')" $BDD
mutate AC2-a "unknown comic shown as a failure" $DET \
  "s.replace('failure is ApiNotFound', 'failure is ApiClientError')" $BDD
mutate AC2-c "a comic's double Retry sends two requests" $DET \
  "s.replace('        if (_loading) {', '        if (_loading && _flow.state.comicId.value < 0) {')" $BDD
mutate AC3-c "the wiring sends a character to the comic location" $NAV \
  "s.replace('AppLocations.character(id.value)', 'AppLocations.comic(id.value)')" $ROUTES $APP
mutate AC4-b "German favourite label left in English" $CD/lib/src/l10n/comics_details_de.arb \
  "s.replace('\"Zu Favoriten hinzufügen\"', '\"Add to favourites\"')" $BDD
mutate AC5-c "a related comic opens the wrong id" $CL/lib/src/presentation/bloc/related_comics_bloc.dart \
  "s.replace('_navigator.openComic(id);', '_navigator.openComic(ComicId(id.value + 1));')" $CL_BDD
mutate AC6-b "a cancelled sign-in still writes" $FAV \
  "s.replace('        emit(const ComicFavouriteState.ready(favourite: false));\n        return;\n      }\n      // A new session', '        emit(const ComicFavouriteState.ready(favourite: false));\n      }\n      // A new session')" $BDD
mutate AC6-e "no guard against a second tap" $FAV \
  "s.replace('if (_busy || state is _Loading) {', 'if (state is _Loading) {')" $BDD
mutate AC6-f "not optimistic" $FAV \
  "s.replace('emit(ComicFavouriteState.ready(favourite: wanted, saving: true));', 'emit(ComicFavouriteState.ready(favourite: current, saving: true));')" $BDD
mutate R7-a "the sheet closes on the barrier while signing in" $SHEET \
  "s.replace('canPop: !_busy,', 'canPop: true,')" $ROUTES
mutate R7-b "a sheet closed mid sign-in answers false" $SHEET \
  "s.replace('return answer ?? await (attempt.inFlight ?? Future.value(false));', 'return answer ?? false;')" $ROUTES
mutate R8-a "no re-read for the new session after sign-in" $FAV \
  "s.replace('if (fresh.getOrElse(() => false)) {', 'if (fresh.getOrElse(() => false) && !_busy) {')" $BDD
mutate R8-c "a session change during a tap is not applied after it" $FAV \
  "s.replace('        }\n        if (_session.epoch != _shownEpoch) {\n          await _load(emit);\n        }\n', '        }\n')" $BDD
mutate R8-d "a read that outlived its session is shown" $FAV \
  "s.replace('    if (_session.epoch != epoch) {\n      return _load(emit);\n    }\n', '')" $BDD
mutate R2-a "the fixture's cast summary out of characterIds order" utility/mc_fixtures_comics/lib/src/data/universe.dart \
  "s.replace('        for (final id in ids)\n', '        for (final id in ids.reversed)\n')" //utility/mc_fixtures_comics:provider_contract_test
mutate R3 "a group-prefixed RouteTargets escapes the Flow check" tool/mc_arch_check/lib/src/arch_check.dart \
  "s.replace(\"!declaration.namePart.typeName.lexeme.endsWith('RouteTargets')\", \"declaration.namePart.typeName.lexeme != 'RouteTargets'\")" $ARCHCHECK
mutate AC7-a "barrel exports a page" $CD/lib/comics_details.dart \
  "s + \"export 'package:comics_details/src/presentation/page/comic_details_page.dart' show ComicDetailsPage;\n\"" $ARCH

say ""
say "$killed of $n mutations killed by a failing test"
[[ -z "$(git status --porcelain)" ]] || { say "TREE NOT CLEAN AFTER RUN"; rc=1; }
exit $rc
