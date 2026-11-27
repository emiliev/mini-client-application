#!/bin/bash
# T-0064: mutation check of the trivia_quiz IX exemplar: the engine's
# scoring, streak, timeout and hint, the three blocs, the results POST, the
# painters, the wiring and the trivia fixture's hint rule.
#
# Every mutation edits one source file, runs the named test targets, and must
# make a test FAIL ("FAILED in" in Bazel's summary). Outcomes:
#   KILLED    a test failed.
#   BROKEN    the build did not complete ("Build did NOT complete", a compile,
#             analyzer or format error): NOT evidence, counted as a failure.
#   TIMEOUT   a test timed out: not a kill, counted as a failure.
#   SURVIVED  every test passed: a hole in the tests.
# The unmutated tree must pass first. The script REFUSES a dirty tree (any
# uncommitted or untracked file) and sets its restore trap before it edits
# anything; after each mutation the file is restored with `git checkout` and
# the restore is verified.
#
#   MC_TASK=T-0064 MC_ROLE=engineer documents/evidence/T-0064/engineer/mutations.sh
#   MC_ONLY="M01 W2" ...   only the named mutations (after the baseline)
#   MC_CHECK_ONLY=1 ...    only check that every pattern applies (no Bazel)
#
# Exit 0 only if every mutation was applied and killed. The log goes to
# /tmp/mc-$MC_TASK-$MC_ROLE-mutations.log.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TASK="${MC_TASK:-T-0064}"
ROLE="${MC_ROLE:-engineer}"
OB="${MC_OUTPUT_BASE:-/tmp/mc-ob-$TASK-$ROLE}"
LOG="/tmp/mc-$TASK-$ROLE-mutations.log"
CHECK_ONLY="${MC_CHECK_ONLY:-}"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
bz() { tool/bazelw --output_base="$OB" "$@"; }

# Also in check-only mode: the restore trap checks the files out, which
# would drop uncommitted work in them.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "REFUSING TO RUN: the tree is dirty (commit or remove these first):" >&2
  git status --short >&2
  exit 2
fi
: > "$LOG"

F=feature/trivia/trivia_quiz/lib/src
BLOC=$F/presentation/bloc
W=app/wiring/chronicle_wiring/lib/src
FX=utility/mc_fixtures_editorial/lib/src
S="$F/domain/engine/scoring.dart"
E="$F/domain/engine/trivia_engine.dart"
P="$BLOC/trivia_play_bloc.dart"
R="$BLOC/trivia_results_bloc.dart"
U="$BLOC/trivia_setup_bloc.dart"
REPO_="$F/domain/repository/trivia_quiz_repository.dart"
MAP="$F/domain/model/trivia_mapper.dart"
AN="$F/domain/model/trivia_analytics.dart"
FILES=(
  "$S" "$E" "$P" "$R" "$U" "$REPO_" "$MAP" "$AN"
  "$F/flow/trivia_quiz_flow.dart"
  "$F/presentation/page/trivia_play_page.dart" "$F/presentation/page/trivia_results_page.dart"
  "$F/presentation/page/trivia_setup_page.dart" "$F/presentation/widget/countdown.dart"
  "$F/presentation/widget/trivia_common.dart" "$F/presentation/widget/score_breakdown.dart"
  "$F/presentation/painter/countdown_ring_painter.dart" "$F/presentation/painter/streak_meter_painter.dart"
  "$W/navigators/trivia_quiz_navigator_impl.dart" "$W/routes/route_targets_impl.dart"
  "$W/routes/trivia_routes.dart" "$W/di/chronicle_wiring_di_initializer.dart"
  app/wiring/app_core/lib/src/locations/app_locations.dart
  "$FX/data/scoring.dart" "$FX/data/bank.dart" "$FX/handlers/trivia_handlers.dart"
)
restore_all() { git checkout -- "${FILES[@]}" 2>/dev/null; }
trap restore_all EXIT INT TERM

T_BDD=//feature/trivia/trivia_quiz:bdd_test
T_SCOPE=//feature/trivia/trivia_quiz:flow_scope_test
T_PAINT=//feature/trivia/trivia_quiz:painter_test
T_CONTRACT=//feature/trivia/trivia_quiz:contract_test
T_FEAT="$T_BDD $T_SCOPE $T_PAINT $T_CONTRACT"
T_WIRE=//app/wiring/chronicle_wiring:routes_test
T_FIX="//utility/mc_fixtures_editorial:scoring_test //utility/mc_fixtures_editorial:validation_test //utility/mc_fixtures_editorial:provider_contract_test"

run() { bz test --nocache_test_results --test_timeout=900 "$@" 2>&1 | tr '\r' '\n'; }

if [[ -z "$CHECK_ONLY" ]]; then
  base="$(run $T_FEAT $T_WIRE $T_FIX)"
  if grep -q -a -E "FAILED|NO STATUS|^ERROR|Build did NOT complete" <<< "$base"; then
    say "BASELINE FAILS"
    grep -a -E "FAILED|^ERROR|Build did NOT" <<< "$base" | tee -a "$LOG"
    exit 1
  fi
  say "baseline: PASS"
fi

rc=0; n=0; killed=0
# mutate ID "what" file "targets" old new [old new ...]
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
  if [[ -n "$CHECK_ONLY" ]]; then
    say "$id $what: applies"; git checkout -- "$file"; return
  fi
  [[ "$file" == *.dart ]] && fvm dart format "$file" > /dev/null
  local out; out="$(run $targets)"
  if grep -q -a -E "Build did NOT complete|^ERROR|FAILED TO BUILD" <<< "$out"; then
    say "$id $what: BROKEN (build failed: not evidence)"; rc=1
  elif grep -q -a "FAILED in" <<< "$out"; then
    local first; first="$(grep -a -m1 'FAILED in' <<< "$out" | awk '{print $1}')"
    say "$id $what: KILLED ($first)"; killed=$((killed + 1))
  elif grep -q -a "TIMEOUT in" <<< "$out"; then
    say "$id $what: TIMEOUT (not a kill)"; rc=1
  else
    say "$id $what: SURVIVED"; rc=1
  fi
  git checkout -- "$file"
  git diff --quiet -- "$file" || { say "RESTORE FAILED: $file"; rc=1; }
}


# --- the engine's scoring (CONTRACT.md "Scoring") --------------------------
mutate S01 "the limit itself is still in time" "$S" "$T_BDD" \
  'elapsedMs >= question.limitMs' 'elapsedMs > question.limitMs'
mutate S02 "a wrong choice is judged correct" "$S" "$T_BDD" \
  'return choiceId == question.correctChoiceId' 'return choiceId != question.correctChoiceId'
mutate S03 "base points 101" "$S" "$T_BDD" \
  'const int basePoints = 100;' 'const int basePoints = 101;'
mutate S04 "time bonus at most 49" "$S" "$T_BDD" \
  'const int maxTimeBonus = 50;' 'const int maxTimeBonus = 49;'
mutate S05 "streak step 26" "$S" "$T_BDD" \
  'const int streakStep = 25;' 'const int streakStep = 26;'
mutate S06 "hint costs 49" "$S" "$T_BDD" \
  'const int hintPenalty = 50;' 'const int hintPenalty = 49;'
mutate S07 "the time bonus rounds up" "$S" "$T_BDD" \
  'final timeBonus = maxTimeBonus * (limitMs - elapsedMs) ~/ limitMs;' 'final timeBonus = (maxTimeBonus * (limitMs - elapsedMs) + limitMs - 1) ~/ limitMs;'
mutate S08 "the first of a run already gets a streak bonus" "$S" "$T_BDD" \
  'streakStep * (streak - 1)' 'streakStep * streak'
mutate S09 "the hint costs nothing" "$S" "$T_BDD" \
  '(hint ? hintPenalty : 0)' '(hint && streak < 0 ? hintPenalty : 0)'
mutate S10 "a wrong answer earns points" "$S" "$T_BDD" \
  'if (outcome != AnswerOutcome.correct) {' 'if (outcome == AnswerOutcome.timeout) {'

# --- the engine: streak, timeout, hint, round ------------------------------
mutate E01 "a miss does not reset the streak" "$E" "$T_BDD" \
  '_streak = outcome == AnswerOutcome.correct ? _streak + 1 : 0;' '_streak = outcome == AnswerOutcome.correct ? _streak + 1 : _streak;'
mutate E02 "the hint penalises every later answer" "$E" "$T_BDD" \
  'final hint = _hintedQuestionId == q.id;' 'final hint = _hintedQuestionId != null;'
mutate E03 "the hint can be used twice" "$E" "$T_BDD" \
  '_hintedQuestionId == null && _phase == RoundPhase.asking' '_phase == RoundPhase.asking'
mutate E04 "the hint hides only one wrong choice" "$E" "$T_BDD" \
  'if (c.id != question.correctChoiceId && c.id != keep) c.id,' 'if (c.id != question.correctChoiceId && c.id == keep) c.id,'
mutate E05 "a timeout is submitted at 0 ms" "$E" "$T_BDD" \
  'return _resolve(null, question.limitMs);' 'return _resolve(null, 0);'
mutate E06 "the round never finishes" "$E" "$T_BDD" \
  '    if (isLast) {' '    if (_index > total) {'
mutate E07 "a timeout counts as correct" "$E" "$T_BDD" \
  '_answers.where((a) => a.outcome == AnswerOutcome.correct).length' '_answers.where((a) => a.outcome != AnswerOutcome.wrong).length'

# --- the play bloc: time, pauses, hint flag, quit, analytics ---------------
mutate P01 "the background does not pause" "$P" "$T_BDD" \
  '_setPause(emit, _Pause.background, paused: !foreground);' '_setPause(emit, _Pause.background, paused: !foreground && foreground);'
mutate P02 "a covering screen does not pause" "$P" "$T_SCOPE" \
  '_setPause(emit, _Pause.covered, paused: !shown);' '_setPause(emit, _Pause.covered, paused: !shown && shown);'
mutate P03 "a resumed question gets its whole limit again" "$P" "$T_BDD" \
  'Duration(milliseconds: engine.remainingMs(_clock.elapsedMs)),' 'Duration(milliseconds: engine.question.limitMs),'
mutate P04 "the hint flag is inverted" "$P" "$T_BDD" \
  '_hintOffered = _flags.variant(triviaHint) == triviaHintOn;' '_hintOffered = _flags.variant(triviaHint) != triviaHintOn;'
mutate P05 "the hint flag is read on every frame" "$P" "$T_SCOPE" \
  'hintOffered: _hintOffered && engine.canUseHint,' 'hintOffered: _flags.variant(triviaHint) == triviaHintOn && engine.canUseHint,'
mutate P06 "quitting while loading does not leave" "$P" "$T_BDD" \
  $'      _leave();\n      return;\n    }\n    if (_confirmingQuit) {' $'      return;\n    }\n    if (_confirmingQuit) {'
mutate P07 "Cancel leaves too" "$P" "$T_BDD" \
  '    if (confirmed) {' '    if (confirmed || !confirmed) {'
mutate P08 "a linked round is left inside the flow" "$P" "$T_BDD" \
  '    if (_flow.state.linked) {' '    if (!_flow.state.linked) {'
mutate P09 "round_finished tracks the correct count" "$P" "$T_BDD" \
  '_tracker.roundFinished(engine.score);' '_tracker.roundFinished(engine.correct);'
mutate P10 "the elapsed bucket is off by one" "$AN" "$T_BDD" \
  "return 'q\${4 * elapsedMs ~/ limitMs + 1}';" "return 'q\${4 * elapsedMs ~/ limitMs}';"
mutate P11 "a timeout is tracked as correct" "$AN" "$T_BDD" \
  "'correct': outcome == AnswerOutcome.correct," "'correct': outcome != AnswerOutcome.wrong,"
mutate P12 "round_started swaps its params" "$AN" "$T_BDD" \
  "{'category': category, 'difficulty': difficulty}," "{'category': difficulty, 'difficulty': category},"

# --- the results bloc: the POST, the session, the mismatch, the comic ------
mutate R01 "signed in, nothing is saved" "$R" "$T_BDD" \
  $'        _started = true;\n        if (_session.isSignedIn) {' $'        _started = true;\n        if (_session.isSignedIn && _session.epoch < 0) {'
mutate R02 "an answer for a session that is gone is shown" "$R" "$T_BDD" \
  $'    if (_session.epoch != epoch) {\n      // The answer belongs' $'    if (_session.epoch != epoch && epoch < 0) {\n      // The answer belongs'
mutate R03 "the result POST is not pinned" "$REPO_" "$T_BDD" \
  $'      resultRequest(roundId, answers),\n      extras: authPinned(epoch),' $'      resultRequest(roundId, answers),\n      extras: const {},'
mutate R04 "a cancelled sign-in saves when someone signed in elsewhere" "$R" "$T_BDD" \
  'if (!signedIn || !_session.isSignedIn) {' 'if ((!signedIn && signedIn) || !_session.isSignedIn) {'
mutate R05 "a yes with nobody signed in still posts" "$R" "$T_BDD" \
  'if (!signedIn || !_session.isSignedIn) {' 'if (!signedIn) {'
mutate R06 "Retry also runs while saving" "$R" "$T_BDD" \
  $'        if (state is! _NotSaved) {\n          return;' $'        if (state is _Saved) {\n          return;'
mutate R07 "a double tap asks to sign in twice" "$R" "$T_BDD" \
  '    if (state is! _SignedOut) {' '    if (state is _Saved) {'
mutate R08 "a mismatch is not reported" "$R" "$T_BDD" \
  'if (server.score != finished.score && !_mismatchReported) {' 'if (server.score < 0 && !_mismatchReported) {'
mutate R09 "every save reports a mismatch" "$R" "$T_BDD" \
  'if (server.score != finished.score && !_mismatchReported) {' 'if (server.score >= 0 && !_mismatchReported) {'
mutate R10 "the engine's score is shown over the server's" "$F/presentation/page/trivia_results_page.dart" "$T_BDD" \
  'final score = server?.score ?? finished.score;' 'final score = finished.score;'
mutate R11 "a double tap opens the comic twice" "$R" "$T_BDD" \
  'if ((_openGuard?.isActive ?? false) && _opened == id) {' 'if ((_openGuard?.isActive ?? false) && _opened != id) {'
mutate R12 "Play again replays the same seed" "$R" "$T_BDD" \
  'seed: _seeds.next(),' 'seed: round.seed,'
mutate R13 "signed out, the result is posted anyway" "$R" "$T_BDD" \
  $'        _started = true;\n        if (_session.isSignedIn) {' $'        _started = true;\n        if (_session.isSignedIn || _session.epoch >= 0) {'
mutate R14 "every saved result says New best" "$F/presentation/page/trivia_results_page.dart" "$T_BDD" \
  'if (server.isNewBest)' 'if (server.bestScore > 0)'
mutate R15 "a dropped answer signed in shows the sign-in offer" "$R" "$T_BDD" \
  $'        _session.isSignedIn\n            ? const TriviaResultsState.notSaved(' $'        !_session.isSignedIn\n            ? const TriviaResultsState.notSaved('

# --- the setup bloc: best scores and the session ---------------------------
mutate U01 "signed in, no best is read" "$U" "$T_BDD" \
  $'    if (!_session.isSignedIn) {\n      _showBest(emit, null);' $'    if (_session.epoch >= 0) {\n      _showBest(emit, null);'
mutate U02 "signed out, the best is asked for" "$U" "$T_BDD" \
  $'    if (!_session.isSignedIn) {\n      _showBest(emit, null);' $'    if (!_session.isSignedIn && _session.epoch < 0) {\n      _showBest(emit, null);'
mutate U03 "the session is not followed" "$U" "$T_BDD" \
  $'          (_) => add(const _SessionChanged()),\n        );\n        await _loadCategories(emit);' $'          (_) {},\n        );\n        await _loadCategories(emit);'
mutate U04 "coming back does not read the best again" "$F/presentation/page/trivia_setup_page.dart" "$T_BDD" \
  '} else if (visible && !_visible) {' '} else if (visible && !_visible && !visible) {'
mutate U05 "a best answer for a gone session is kept" "$U" "$T_BDD" \
  '    if (_session.epoch != epoch) {' '    if (_session.epoch != epoch && epoch < 0) {'
mutate U06 "a double tap on Start opens two rounds" "$U" "$T_BDD" \
  'when _flow.state.round == null' 'when ready.categories.isNotEmpty'
mutate U07 "no categories is not the empty state" "$U" "$T_BDD" \
  '    if (categories.isEmpty) {' '    if (categories.length > 99) {'
mutate U08 "the best read is not pinned" "$REPO_" "$T_BDD" \
  '(await _api.getBest(extras: authPinned(epoch))).toDomain(),' '(await _api.getBest(extras: const {})).toDomain(),'

# --- the mapper -------------------------------------------------------------
mutate D01 "the limit is 1001 ms per second" "$MAP" "$T_BDD" \
  'limitMs: timeLimitSeconds * 1000,' 'limitMs: timeLimitSeconds * 1001,'
mutate D02 "no question links its comic" "$MAP" "$T_BDD" \
  'final id? => ComicId(id),' 'final id? => id < 0 ? ComicId(id) : null,'
mutate D03 "the hint is not sent" "$MAP" "$T_BDD" \
  'hint: a.hint ? true : null,' 'hint: a.hint && a.points < 0 ? true : null,'
mutate D04 "the best is read one point high" "$MAP" "$T_BDD" \
  'Map<String, int> toDomain() => {for (final b in best) b.category: b.bestScore};' 'Map<String, int> toDomain() => {for (final b in best) b.category: b.bestScore + 1};'
mutate D05 "the server's points are read one high" "$MAP" "$T_BDD $T_CONTRACT" \
  'points: [for (final b in breakdown) b.points],' 'points: [for (final b in breakdown) b.points + 1],'

# --- pages, painters, flow --------------------------------------------------
mutate G01 "reduce motion is ignored" "$F/presentation/widget/countdown.dart" "$T_BDD" \
  'child: MediaQuery.disableAnimationsOf(context)' 'child: MediaQuery.disableAnimationsOf(context) && limitMs < 0'
mutate G02 "a quarter left is not yet urgent" "$F/presentation/widget/countdown.dart" "$T_PAINT" \
  'remainingMs * 4 <= limitMs' 'remainingMs * 4 < limitMs'
mutate G03 "the seconds left round down" "$F/presentation/widget/trivia_common.dart" "$T_BDD" \
  '(remainingMs + 999) ~/ 1000' 'remainingMs ~/ 1000'
mutate G04 "only paused pauses (not inactive or hidden)" "$F/presentation/page/trivia_play_page.dart" "$T_BDD" \
  'foreground: state == AppLifecycleState.resumed,' 'foreground: state != AppLifecycleState.paused,'
mutate G05 "the setup never knows it is covered" "$F/presentation/page/trivia_setup_page.dart" "$T_BDD" \
  '(ModalRoute.of(context)?.isCurrent ?? true);' '(ModalRoute.of(context) != null);'
mutate G06 "the ring draws half the time left" "$F/presentation/painter/countdown_ring_painter.dart" "$T_PAINT" \
  '2 * math.pi * left,' 'math.pi * left,'
mutate G07 "the ring starts at 9 o'clock" "$F/presentation/painter/countdown_ring_painter.dart" "$T_PAINT" \
  '-math.pi / 2,' '-math.pi,'
mutate G08 "the meter lights one pill too many" "$F/presentation/painter/streak_meter_painter.dart" "$T_PAINT" \
  'i < streak ? lit : unlit' 'i <= streak ? lit : unlit'
mutate G09 "the meter's pills have no gaps" "$F/presentation/painter/streak_meter_painter.dart" "$T_PAINT" \
  'final left = i * (width + gap);' 'final left = i * width;'
mutate G10 "the donut shows wrong answers as correct" "$F/presentation/widget/score_breakdown.dart" "$T_PAINT" \
  'value: correct.toDouble(),' 'value: wrong.toDouble(),'
mutate G11 "leaving a linked round does not pop it" "$F/flow/trivia_quiz_flow.dart" "$T_BDD" \
  'onComplete: (_) => unawaited(Navigator.maybeOf(context)?.maybePop()),' 'onComplete: (_) => unawaited(Future<void>.value()),'
mutate G12 "a linked round has a setup page" "$F/flow/trivia_quiz_flow.dart" "$T_BDD" \
  'TriviaQuizFlowState(linked: linked != null, round: linked),' 'TriviaQuizFlowState(linked: linked == null, round: linked),'
mutate G13 "the results screen is misnamed" "$AN" "$T_BDD" \
  "const String triviaResultsScreen = 'trivia_results';" "const String triviaResultsScreen = 'trivia_result';"

# --- the wiring -------------------------------------------------------------
mutate W01 "openComic opens the next comic" "$W/navigators/trivia_quiz_navigator_impl.dart" "$T_WIRE" \
  'AppLocations.comic(id.value)' 'AppLocations.comic(id.value + 1)'
mutate W02 "the sign-in sheet gives the wrong reason" "$W/navigators/trivia_quiz_navigator_impl.dart" "$T_WIRE" \
  "reason: 'to save your score'," "reason: 'to sign in',"
mutate W03 "a link without a category plays easy" "$W/routes/route_targets_impl.dart" "$T_WIRE" \
  "category: category ?? 'all'," "category: category ?? 'easy',"
mutate W04 "the clock counts microseconds" "$W/di/chronicle_wiring_di_initializer.dart" "$T_WIRE" \
  'int chronicleClock() => _monotonic.elapsedMilliseconds;' 'int chronicleClock() => _monotonic.elapsedMicroseconds;'
mutate W05 "the seeds take 8 values" "$W/di/chronicle_wiring_di_initializer.dart" "$T_WIRE" \
  'int chronicleSeed() => _random.nextInt(1 << 31);' 'int chronicleSeed() => _random.nextInt(1 << 3);'
mutate W06 "AppLocations spells the seed differently" app/wiring/app_core/lib/src/locations/app_locations.dart "$T_WIRE" \
  "if (seed != null) 'seed': '\$seed'," "if (seed != null) 's': '\$seed',"
mutate W07 "the round route is misnamed" "$W/routes/trivia_routes.dart" "$T_WIRE" \
  "name: 'trivia_play'" "name: 'trivia_round'"
mutate W08 "a link's seed is dropped" "$W/routes/route_targets_impl.dart" "$T_WIRE" \
  '    seed: seed,' '    seed: null,'

# --- the fixture's hint rule (mc_fixtures_editorial) -------------------------
mutate F01 "one hint is too many" "$FX/handlers/trivia_handlers.dart" "$T_FIX" \
  '      if (hints > hintsPerRound) {' '      if (hints >= hintsPerRound) {'
mutate F02 "a string hint is accepted" "$FX/handlers/trivia_handlers.dart" "$T_FIX" \
  "(entry.containsKey('hint') && entry['hint'] is! bool)" "(entry.containsKey('hint') && entry['hint'] is int)"
mutate F03 "the server's hint costs 49" "$FX/data/scoring.dart" "$T_FIX" \
  'const int hintPenalty = 50;' 'const int hintPenalty = 49;'
mutate F04 "the breakdown marks unhinted answers" "$FX/data/scoring.dart" "$T_FIX" \
  "    if (hint) 'hint': true," "    if (hint || points > 0) 'hint': true,"
mutate F05 "a question links its series as a comic" "$FX/data/bank.dart" "$T_FIX" \
  "if (facts['comicId'] case final int comicId) 'comicId': comicId," "if (facts['seriesId'] case final int comicId) 'comicId': comicId,"
mutate F06 "the server's hint costs nothing" "$FX/data/scoring.dart" "$T_FIX" \
  '(hint ? hintPenalty : 0)' '(hint && streak > 99 ? hintPenalty : 0)'

say ""
say "mutations: $n, killed: $killed"
[[ $rc -eq 0 && $n -gt 0 && $killed -eq $n ]] && say "RESULT: PASS" || say "RESULT: FAIL"
exit $rc
