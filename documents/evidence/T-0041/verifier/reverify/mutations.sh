#!/bin/bash
# T-0041 Verifier re-verification mutations at e053e45: my own (E*, V*) plus
# a sample of 22 of the engineer's 51 (blocks copied verbatim from
# documents/evidence/T-0041/engineer/mutations.sh). Each must make a named
# target FAIL with a failing test; files restored with `git checkout`.
set -uo pipefail
W=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-aedf1b73f30091004
cd "$W"
OB=/tmp/mc-ob-T-0041-verifier
LOG=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/T-0041-verifier/rv/mutations.log
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }
[[ -z "$(git status --porcelain)" ]] || { say "REFUSING: tree not clean"; exit 2; }
ONLY=" $* "
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
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; exit 1; }
}
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
FIX_CONTRACT=//utility/mc_fixtures_comics:provider_contract_test
ROOT_FMT=//app/wiring/app_core:formatters_root_test
AUTH_HARNESS=//utility/mc_test_utils:auth_container_test
FMT_CONTAINER=//utility/mc_test_utils:formatters_container_test
CD_GOLDEN=//feature/comics/comics_details:golden_test
ARCHCHECK=//tool/mc_arch_check:arch_check_test
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

# ---- my own -----------------------------------------------------------------
mutate E1 "the post-sign-in epoch check reverted (block removed)" $FAV \
  "s.replace('      if (_session.epoch != epoch) {\n        // The session changed during the read (a sign-out, another user):\n        // the answer belongs to a session that is gone, so nothing is\n        // written. The tap\'s ending reloads for the current session.\n        return;\n      }\n', '')" $BDD
mutate E2 "own announcements never counted down (page ignores later writes)" $FAV \
  "s.replace('        if (_ownAnnouncements > 0) {\n          _ownAnnouncements--;\n        }', '        if (_ownAnnouncements > 0) {\n        }')" $BDD
mutate E3 "a bus change reloads even during a tap" $FAV \
  "s.replace('        } else if (!_busy) {\n          await _load(emit);', '        } else {\n          await _load(emit);')" $BDD
mutate E4 "the drag guard always claims drags (idle sheet cannot be dragged away)" $SHEET \
  "s.replace('onVerticalDragStart: _busy ? (_) {} : null,', 'onVerticalDragStart: (_) {},')" $ROUTES
mutate V12 "the toggle is not marked saving (enabled during the write)" $FAV \
  "s.replace('emit(ComicFavouriteState.ready(favourite: wanted, saving: true));', 'emit(ComicFavouriteState.ready(favourite: wanted));')" $BDD
mutate V14 "Not now stays enabled while signing in" $SHEET \
  "re.sub(r'onPressed: _busy\s*\?\s*null\s*:\s*\(\) => Navigator\.of\(context\)\.pop\(false\),', 'onPressed: () => Navigator.of(context).pop(false),', s)" $ROUTES
mutate V07 "a sign-out elsewhere is not applied" $FAV \
  "s.replace('if (!_busy && _session.epoch != _shownEpoch) {', 'if (!_busy && _session.epoch != _shownEpoch && _session.isSignedIn) {')" $BDD
mutate V08 "a sign-in elsewhere is not applied" $FAV \
  "s.replace('if (!_busy && _session.epoch != _shownEpoch) {', 'if (!_busy && _session.epoch != _shownEpoch && !_session.isSignedIn) {')" $BDD
mutate V09 "DataChanged published on a failed write too" $FAV \
  "s.replace('      (error) => emit(\n        ComicFavouriteState.saveFailed(error, favourite: current),\n      ),', '      (error) {\n        _bus.publish(const DataChanged(favouritesTopic));\n        emit(ComicFavouriteState.saveFailed(error, favourite: current));\n      },')" $BDD
mutate V11 "a cancelled sign-in still reads the flag (a request)" $FAV \
  "s.replace('      if (!await _navigator.requestSignIn() || !_session.isSignedIn) {\n        _shownEpoch = _session.epoch;', '      if (!await _navigator.requestSignIn() || !_session.isSignedIn) {\n        await _repository.isFavourite(_comicId);\n        _shownEpoch = _session.epoch;')" $BDD
mutate R8-a "no re-read for the new session after sign-in" $FAV \
  "s.replace('if (fresh.getOrElse(() => false)) {', 'if (fresh.getOrElse(() => false) && !_busy) {')" $BDD
mutate R8-c "a session change during a tap is not applied after it" $FAV \
  "s.replace('        }\n        if (_session.epoch != _shownEpoch) {\n          await _load(emit);\n        }\n', '        }\n')" $BDD
mutate R8-d "a read that outlived its session is shown" $FAV \
  "s.replace('    if (_session.epoch != epoch) {\n      return _load(emit);\n    }\n', '')" $BDD

# ---- engineer's sample (verbatim) -------------------------------------------
mutate AC1-a "price shown as raw minor units" $FACTS \
  "s.replace('formatMoney(comic.price, locale)', \"'\${comic.price.minorUnits}'\")" $BDD
mutate AC2-b "Retry does nothing" $PAGE \
  "re.sub(r'onRetry: \(\) => context\.read<ComicDetailsBloc>\(\)\.add\(\s*const ComicDetailsEvent\.load\(\),\s*\)', 'onRetry: () {}', s)" $BDD
mutate AC3-a "openCharacter with the wrong id" $DET \
  "s.replace('_navigator.openCharacter(id);', '_navigator.openCharacter(CharacterId(id.value + 1));')" $BDD
mutate AC4-c "header text column not flexible (overflows)" $HEAD \
  "s.replace('          Expanded(\n            child: Column(', '          SizedBox(\n            width: 400,\n            child: Column(', 1)" $BDD
mutate AC5-a "comic route path drifts from AppLocations" $PW/lib/src/routes/comics_routes.dart \
  "s.replace(\"path: '/comics/:id'\", \"path: '/comic/:id'\")" $ROUTES $APP
mutate AC6-c "DataChanged published twice" $FAV \
  "s.replace('_bus.publish(const DataChanged(favouritesTopic));', '_bus..publish(const DataChanged(favouritesTopic))..publish(const DataChanged(favouritesTopic));')" $BDD
mutate AC6-d "no rollback after a failed write" $FAV \
  "s.replace('ComicFavouriteState.saveFailed(error, favourite: current)', 'ComicFavouriteState.saveFailed(error, favourite: wanted)')" $BDD
mutate AC6-g "no inline error after a failed write" $TOGGLE \
  "s.replace('            l10n.comicsDetailsFavouriteSaveFailed,', '            null,')" $BDD
mutate AC6-h "the wiring answers true without the sheet" $NAV \
  "s.replace('return showFixtureSignInSheet(context, _auth);', 'return true;')" $ROUTES
mutate R1-a "test container does not load the formatters" utility/mc_test_utils/lib/src/test_container.dart \
  "s.replace('    const FormattersDIInitializer(),', '    McDIInitializer((_, _) => const FormattersDIInitializer()),')" $FMT_CONTAINER
mutate R9 "a double Retry of the related comics sends two requests" $CL/lib/src/presentation/bloc/related_comics_bloc.dart \
  "s.replace('        if (_loading) {', '        if (_loading && _character.name.isEmpty) {')" $CL_BDD
mutate R10 "signing in shows the toggle as a favourite" $TOGGLE \
  "s.replace('signingIn: () => (false, false, null),', 'signingIn: () => (true, false, null),')" $BDD
mutate R11 "the harness drops the request headers" utility/mc_test_utils/lib/src/backend_harness.dart \
  "s.replace(\"          for (final e in options.headers.entries) e.key: '\${e.value}',\n\", '')" $BDD $AUTH_HARNESS
mutate F1 "a session change during the post-sign-in read still writes" $FAV \
  "s.replace('      if (_session.epoch != epoch) {\n        // The session changed during the read', '      if (_session.epoch != epoch && _session.userId == \'nobody\') {\n        // The session changed during the read')" $BDD
mutate F2 "Not now stays enabled while signing in (Verifier V14)" $SHEET \
  "re.sub(r'onPressed: _busy\s*\?\s*null\s*:\s*\(\) => Navigator\.of\(context\)\.pop\(false\),', 'onPressed: () => Navigator.of(context).pop(false),', s)" $ROUTES
mutate F3 "the sheet can be dragged away while signing in" $SHEET \
  "s.replace('onVerticalDragStart: _busy ? (_) {} : null,', 'onVerticalDragStart: null,')" $ROUTES
mutate F4 "the toggle stays enabled during the write (Verifier V12)" $FAV \
  "s.replace('emit(ComicFavouriteState.ready(favourite: wanted, saving: true));', 'emit(ComicFavouriteState.ready(favourite: wanted));')" $BDD
mutate F5-a "the bloc ignores DataChanged('favourites') from another page" $FAV \
  "s.replace('.listen((_) => add(const _FavouritesChanged()));', '.listen((_) {});')" $BDD
mutate F5-b "the bloc reloads after its own announcement" $FAV \
  "s.replace('        _ownAnnouncements++;\n', '')" $BDD
mutate F6-a "a related comic shows no cover" $CL/lib/src/presentation/widget/related_comics.dart \
  "re.sub(r'leading: (McImage\([^)]*\)),', r'leading: Offstage(child: \1),', s, flags=re.S)" $CL_BDD
mutate F6-b "the facts rows lose their spacing token" $FACTS \
  "s.replace('vertical: McSpacing.sm', 'vertical: 6')" $CD_GOLDEN
mutate AC7-b "SessionReader not forwarded (Session instead)" $CD/lib/src/di/flow_scope.dart \
  "s.replace('  RootImport<SessionReader>(),', '  RootImport<Session>(),')" $FLOW

say ""
say "$killed of $n mutations killed by a failing test"
[[ -z "$(git status --porcelain)" ]] || { say "TREE NOT CLEAN AFTER RUN"; rc=1; }
exit $rc
