#!/bin/bash
# T-0060 engineer mutation checks: each mutation of the trivia fixture must
# turn at least one test red. A mutation that survives, or that fails to
# build, fails this script. Scoring, the streak, the timeout boundary, the
# validation codes, ownership, determinism and the choice shuffling are
# pinned one by one.
#
#   MC_TASK=T-0060 MC_ROLE=engineer documents/evidence/T-0060/engineer/mutations.sh
#
# Counting: "killed" needs a `FAILED in` test line. A build that does not
# complete (`Build did NOT complete`) is "broken", never killed. Refuses to
# run on a dirty tree: every mutation is undone with `git checkout -- <pkg>`,
# which would also discard uncommitted edits.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
: "${MC_TASK:?set MC_TASK, e.g. T-0060}"
: "${MC_ROLE:?set MC_ROLE, e.g. engineer}"
P=utility/mc_fixtures_editorial
if [[ -n "$(git status --porcelain)" ]]; then
  echo "refusing to run: the working tree is dirty" >&2
  git status --porcelain >&2
  exit 2
fi
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
SC=$P/lib/src/data/scoring.dart
RD=$P/lib/src/data/round.dart
BK=$P/lib/src/data/bank.dart
TH=$P/lib/src/handlers/trivia_handlers.dart
DOM=$P/lib/src/domain.dart
LOG="$(mktemp -t "mc-$MC_TASK-$MC_ROLE-mut.XXXXXX")"
# The restore trap is set before the first edit.
restore() { git checkout -- "$P"; }
trap 'restore; rm -f "$LOG"' EXIT
trap 'exit 130' INT TERM
killed=0
survived=0
broken=0
total=0
survivors=()

run_tests() {
  tool/bazelw --output_base="$OB" test //$P/... > "$LOG" 2>&1
}

# mutate <name> <file> <old> <new>   (<old> must occur exactly once)
mutate() {
  local name="$1" file="$2" old="$3" new="$4"
  # MC_ONLY (a regex on the name) re-runs a subset, e.g. after a test was added.
  if [[ -n "${MC_ONLY:-}" && ! "$name" =~ $MC_ONLY ]]; then return; fi
  total=$((total + 1))
  echo "=== $name"
  if ! python3 -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
n = s.count(old)
if n != 1:
    sys.exit("pattern occurs %d times (need 1): %s" % (n, old))
open(p, "w").write(s.replace(old, new, 1))
' "$file" "$old" "$new"; then
    echo "    PATTERN PROBLEM"; broken=$((broken + 1)); restore; return
  fi
  # The build checks formatting, so a mutation is formatted like the source.
  fvm dart format "$file" > /dev/null 2>&1
  if [[ -n "${MC_DRY:-}" ]]; then
    echo "    pattern ok (dry run)"; restore; return
  fi
  run_tests
  local failed
  failed="$(tr '\r' '\n' < "$LOG" | grep -aE '^//.*FAILED in' | sed 's/ *FAILED in.*//' | sed 's|//utility/mc_fixtures_editorial:||' | tr '\n' ' ')"
  if tr '\r' '\n' < "$LOG" | grep -aq 'Build did NOT complete'; then
    echo "    BUILD ERROR (broken, does not count as killed)"
    tr '\r' '\n' < "$LOG" | grep -aE 'error|warning|info -' | head -3
    broken=$((broken + 1))
  elif [[ -n "$failed" ]]; then
    echo "    KILLED by: $failed"
    killed=$((killed + 1))
  else
    echo "    SURVIVED"; survived=$((survived + 1)); survivors+=("$name")
  fi
  restore
}

# Baseline: the unmutated tree must pass (skipped in a dry run, which only
# checks that every pattern occurs exactly once).
[[ -n "${MC_DRY:-}" ]] || run_tests || { echo "BASELINE FAILS"; tr '\r' '\n' < "$LOG" | tail -20; exit 1; }
echo "baseline PASS"

# --- scoring: the timeout boundary ------------------------------------------
mutate "S1 elapsed equal to the limit is not a timeout" $SC 'answer.elapsedMs >= limitMs' 'answer.elapsedMs > limitMs'
mutate "S2 the limit minus 1 ms is a timeout" $SC 'answer.elapsedMs >= limitMs' 'answer.elapsedMs >= limitMs - 1'
mutate "S3 the limit plus 1 ms is not a timeout" $SC 'answer.elapsedMs >= limitMs' 'answer.elapsedMs >= limitMs + 1'
mutate "S4 no choice is not a timeout" $SC 'answer.choiceId == null ||' "answer.choiceId == 'c0' ||"
mutate "S5 the limit is 1001 ms per second" $SC 'q.timeLimitSeconds * 1000' 'q.timeLimitSeconds * 1001'
# --- scoring: points, bonus, streak -----------------------------------------
mutate "S6 base is 101" $SC 'const int basePoints = 100;' 'const int basePoints = 101;'
mutate "S7 the time bonus is at most 51" $SC 'const int maxTimeBonus = 50;' 'const int maxTimeBonus = 51;'
mutate "S8 the streak step is 26" $SC 'const int streakStep = 25;' 'const int streakStep = 26;'
mutate "S9 the time bonus rounds up" $SC 'maxTimeBonus * (limitMs - answer.elapsedMs) ~/ limitMs' '(maxTimeBonus * (limitMs - answer.elapsedMs) + limitMs - 1) ~/ limitMs'
mutate "S10 the time bonus rounds half up" $SC 'maxTimeBonus * (limitMs - answer.elapsedMs) ~/ limitMs' '(2 * maxTimeBonus * (limitMs - answer.elapsedMs) + limitMs) ~/ (2 * limitMs)'
mutate "S11 the bonus ignores the elapsed time" $SC 'maxTimeBonus * (limitMs - answer.elapsedMs) ~/ limitMs' 'maxTimeBonus * limitMs ~/ limitMs'
mutate "S12 the bonus counts from 1 ms" $SC 'maxTimeBonus * (limitMs - answer.elapsedMs) ~/ limitMs' 'maxTimeBonus * (limitMs - answer.elapsedMs - 1) ~/ limitMs'
mutate "S13 the first correct answer already earns a streak step" $SC 'streakStep * (streak - 1)' 'streakStep * streak'
mutate "S14 the streak bonus is capped at 3 steps" $SC 'streakStep * (streak - 1)' 'streakStep * (streak > 4 ? 3 : streak - 1)'
mutate "S15 the streak grows by 2" $SC '      streak++;' '      streak += 2;'
mutate "S16 a wrong answer keeps the streak" $SC '    } else if (answer.choiceId != q.correctChoiceId) {
      streak = 0;' '    } else if (answer.choiceId != q.correctChoiceId) {'
mutate "S17 a timeout keeps the streak" $SC '    if (answer.choiceId == null || answer.elapsedMs >= limitMs) {
      streak = 0;' '    if (answer.choiceId == null || answer.elapsedMs >= limitMs) {'
mutate "S18 a wrong answer scores a point" $SC "scored.add(ScoredAnswer(q.id, Outcome.wrong, 0));" "scored.add(ScoredAnswer(q.id, Outcome.wrong, 1));"
mutate "S19 answers are scored in reverse round order" $SC 'for (final q in questions) {' 'for (final q in questions.reversed) {'
mutate "S20 correct counts every non-wrong answer" $SC 'answers.where((a) => a.outcome == Outcome.correct).length' 'answers.where((a) => a.outcome != Outcome.wrong).length'
mutate "S21 the outcome of a timeout is named wrong" $SC "scored.add(ScoredAnswer(q.id, Outcome.timeout, 0));" "scored.add(ScoredAnswer(q.id, Outcome.wrong, 0));"
mutate "S22 the score is the last answer's points" $SC 'answers.fold(0, (sum, a) => sum + a.points)' 'answers.last.points'
# --- rounds: seeds, ids, determinism ------------------------------------------
mutate "R1 the largest seed is 2^31" $RD 'const int maxRoundSeed = 2147483647;' 'const int maxRoundSeed = 2147483648;'
mutate "R2 the seed 2^31-1 is rejected" $RD 'value > maxRoundSeed ? null' 'value >= maxRoundSeed ? null'
mutate "R3 leading zeros are accepted" $RD "RegExp(r'^(0|[1-9][0-9]*)\$');" "RegExp(r'^[0-9]+\$');"
mutate "R4 a signed seed is accepted" $RD "RegExp(r'^(0|[1-9][0-9]*)\$');" "RegExp(r'^[-+]?(0|[1-9][0-9]*)\$');"
mutate "R5 an unknown category in a round id is accepted" $RD '!categories.contains(match.group(1))' 'categories.isEmpty'
mutate "R6 the round id leaves out the seed" $RD "'r-\$category-\$difficulty-\$seed'" "'r-\$category-\$difficulty'"
mutate "R7 a round id of another difficulty is accepted" $RD '(easy|medium|hard)-(0|[1-9][0-9]*)$' '(easy|medium|hard|extreme)-(0|[1-9][0-9]*)$'
mutate "R8 the round seed is not used for the question draw" $RD "final picker = rng.fork('questions');" "final picker = SplitMix64(0);"
mutate "R9 easy and hard rounds share a stream" $RD '.fork(spec.category).fork(spec.difficulty);' '.fork(spec.category);'
mutate "R10 the draw ignores the pool end (biased swap)" $RD 'final j = i + picker.nextInt(pool.length - i);' 'final j = picker.nextInt(pool.length);'
mutate "R11 a round holds 9 questions" $RD 'for (final q in pool.take(roundSize))' 'for (final q in pool.take(roundSize - 1))'
mutate "R12 the category is ignored" $RD 'if ((spec.category == allCategory || q.category == spec.category) &&' 'if ((spec.category.isNotEmpty || q.category == spec.category) &&'
mutate "R13 the difficulty is ignored" $RD 'q.difficulty == spec.difficulty)' 'spec.seed >= 0)'
mutate "R14 the choices are not shuffled" $RD '    final j = rng.nextInt(i + 1);
    final held = list[i];' '    final j = i;
    final held = list[i];'
mutate "R15 the choice shuffle is a cycle (no fixed point)" $RD '    final j = rng.nextInt(i + 1);
    final held = list[i];' '    final j = rng.nextInt(i);
    final held = list[i];'
mutate "R16 every question has the same choice shuffle" $RD ".fork('choices').fork(q.id)" ".fork('choices')"
mutate "R17 the round seed does not shuffle the choices" $RD '_shuffleChoices(q, rng.fork('"'choices'"').fork(q.id))' '_shuffleChoices(q, SplitMix64(0).fork(q.id))'
# --- bank --------------------------------------------------------------------
mutate "B1 a template yields 20 questions" $BK 'const int questionsPerTemplate = 24;' 'const int questionsPerTemplate = 20;'
mutate "B2 the easy limit is 21 s" $BK "'easy': 20," "'easy': 21,"
mutate "B3 the medium limit is 16 s" $BK "'medium': 15," "'medium': 16,"
mutate "B4 the hard limit is 11 s" $BK "'hard': 10," "'hard': 11,"
mutate "B5 the subjects are not shuffled by seed" $BK "_shuffled(subjects, base.fork('subjects'))" "_shuffled(subjects, SplitMix64(1))"
mutate "B6 choice ids start at c0" $BK "TriviaChoice(id: 'c\${i + 1}', text: texts[i])" "TriviaChoice(id: 'c\$i', text: texts[i])"
mutate "B7 the correct id is off by one" $BK "correctChoiceId: 'c\${texts.indexOf(correct) + 1}'," "correctChoiceId: 'c\${texts.indexOf(correct) + 2}',"
mutate "B8 the bank order of choices is not shuffled" $BK 'final texts = _shuffled([correct, ...wrong], rng);' 'final texts = [correct, ...wrong];'
mutate "B9 the question id is not padded" $BK "number.toString().padLeft(2, '0')" "number.toString().padLeft(3, '0')"
mutate "B10 a team question's answer is the origin" $BK 'correct: c.team,' 'correct: c.origin,'
mutate "B11 a power distractor may be the character's own power" $BK 'wrong: _sample(_powers, {...c.powers}, rng),' 'wrong: _sample(_powers, {c.powers.first}, rng),'
mutate "B12 year distractors reach five years away" $BK 'for (var d = -4; d <= 4; d++)' 'for (var d = -5; d <= 5; d++)'
mutate "B13 the debut year question is off by a year" $BK "correct: '\${c.firstAppearanceYear}'," "correct: '\${c.firstAppearanceYear + 1}',"
mutate "B14 one-comic characters are asked about" $BK 'if (appearances.length < 2) {' 'if (appearances.isEmpty) {'
mutate "B15 the latest comic is the first appearance" $BK '        < 0 => a,
        > 0 => b,' '        < 0 => b,
        > 0 => a,'
mutate "B16 a release-date tie goes to the higher id" $BK '_ => a.id <= b.id ? a : b,' '_ => a.id >= b.id ? a : b,'
mutate "B17 first-comic distractors are comics that feature the character" $BK 'if (!other.characterIds.contains(c.id)) other.title,' 'if (other.characterIds.contains(c.id)) other.title,'
mutate "B18 debut years may repeat" $BK 'if (!_debutYearsUsed.add(year)) {' 'if (!_debutYearsUsed.add(year) && year < 0) {'
mutate "B19 debut distractors are characters of the same year" $BK 'if (other.firstAppearanceYear != year) other.name,' 'if (other.firstAppearanceYear == year) other.name,'
mutate "B20 cast distractors are cast members" $BK 'if (!comic.characterIds.contains(c.id)) c.name,' 'if (comic.characterIds.contains(c.id)) c.name,'
mutate "B21 the price cents are wrong" $BK "(cents % 100).toString().padLeft(2, '0')" "(cents % 10).toString().padLeft(2, '0')"
mutate "B22 the comic year is its month" $BK "final year = comic.releaseDate.year;" "final year = comic.releaseDate.month + 1980;"
mutate "B23 a series starts when it ends" $BK "correct: '\${series.startYear}'," "correct: '\${series.endYear}',"
mutate "B24 a series ends when it starts" $BK "correct: '\${series.endYear}'," "correct: '\${series.startYear}',"
mutate "B25 page counts step by 4" $BK 'pages <= 56; pages += 8' 'pages <= 56; pages += 4'
mutate "B26 a comic with no inker is asked about" $BK 'if (holders.length != 1) {' 'if (holders.length > 1) {'
mutate "B27 creator distractors may hold the role" $BK 'wrong: _sample(_creatorNames, holders, rng),' 'wrong: _sample(_creatorNames, {}, rng),'
mutate "B28 the penciller question asks for the inker" $BK "'penciller', 'medium', 'penciled'" "'inker', 'medium', 'penciled'"
mutate "B29 the comic year question is in another category" $BK "'comic_year', 'comics', 'medium'" "'comic_year', 'comics', 'easy'"
mutate "B30 a series image is left out" $BK '      facts: {'"'kind': 'series_start'"', '"'seriesId'"': series.id},
      imageUrl: series.cover.path,' '      facts: {'"'kind': 'series_start'"', '"'seriesId'"': series.id},'
mutate "B31 the image field is dropped from the JSON of questions with one" $BK "if (imageUrl != null) 'imageUrl': imageUrl," "if (imageUrl == null) 'imageUrl': imageUrl,"
mutate "B32 the JSON leaves out the correct choice" $BK "'correctChoiceId': correctChoiceId," "'correctChoiceId': choices.first.id,"
mutate "B33 the JSON time limit is in ms" $BK "'timeLimitSeconds': timeLimitSeconds," "'timeLimitSeconds': timeLimitSeconds * 1000,"
mutate "B34 distractors are two, not three" $BK 'if (out.length == 3) {' 'if (out.length == 2) {'
# --- handlers: validation, auth, ownership -----------------------------------
mutate "H1 any category is accepted" $TH 'if (!_categoryIds(empty: empty).contains(category)) {' "if (category == 'zzz') {"
mutate "H2 any difficulty is accepted" $TH 'if (!difficulties.contains(difficulty)) {' "if (difficulty == 'zzz') {"
mutate "H3 an invalid seed is read as 0" $TH "final seed = parseRoundSeed(request.query['seed']);
  if (seed == null) {" "final seed = parseRoundSeed(request.query['seed']) ?? 0;
  if (seed < 0) {"
mutate "H4 a validation error is a 422" $TH ') => MockResponse.error(400, code, message, extra: extra);' ') => MockResponse.error(422, code, message, extra: extra);'
mutate "H5 unauthenticated is a 403" $TH '  401,
  '"'unauthenticated'"',' '  403,
  '"'unauthenticated'"','
mutate "H6 no bearer falls back to the first user" $TH 'return user == null ? _unauthenticated() : body(user, request, context);' "return user == null && request.method == 'NOPE' ? _unauthenticated() : body(user ?? fixtureUsers.first, request, context);"
mutate "H7 the authorization header is not read" $TH "request.headers['authorization']" "request.headers['x-authorization']"
mutate "H8 a numeric roundId is not a body error" $TH "if (body is! Map || body['roundId'] is! String) {" 'if (body is! Map) {'
mutate "H9 an answer without a questionId is accepted" $TH "entry['questionId'] is! String ||" 'entry.length > 99 ||'
mutate "H10 a numeric choiceId is accepted as a body" $TH "(entry['choiceId'] != null && entry['choiceId'] is! String)" 'entry.length > 99'
mutate "H11 an unknown round is scored as a default round" $TH "        _categoryIds(empty: empty),
      );
      if (spec == null) {" "        _categoryIds(empty: empty),
      ) ?? const RoundSpec('all', 'easy', 42);
      if (spec.seed < 0) {"
mutate "H12 more answers than questions are accepted" $TH 'if (answers.length != questions.length) {' 'if (answers.length < questions.length) {'
mutate "H13 fewer answers than questions are accepted" $TH 'if (answers.length != questions.length) {' 'if (answers.length > questions.length) {'
mutate "H14 an unknown question is accepted" $TH 'if (!byId.containsKey(a['"'questionId'"'])) {' 'if (a['"'questionId'"'] == null) {'
mutate "H15 a repeated answer is accepted" $TH 'if (!seen.add(a['"'questionId'"'])) {' 'if (!seen.add(a['"'questionId'"']) && seen.length > 99) {'
mutate "H16 an unknown choice is accepted" $TH '        if (choice != null &&
            !byId[a['"'questionId'"']]!.choices.any((c) => c.id == choice)) {' "        if (choice == 'zzz') {"
mutate "H17 no choice is rejected as unknown" $TH '        if (choice != null &&
            !byId[a['"'questionId'"']]!' '        if (!byId[a['"'questionId'"']]!'
mutate "H18 elapsed -1 is accepted" $TH 'if (elapsed is! int || elapsed < 0) {' 'if (elapsed is! int || elapsed < -1) {'
mutate "H19 elapsed 0 is rejected" $TH 'if (elapsed is! int || elapsed < 0) {' 'if (elapsed is! int || elapsed < 1) {'
mutate "H20 a non-integer elapsed is accepted" $TH 'if (elapsed is! int || elapsed < 0) {' 'if (elapsed is int && elapsed < 0) {'
mutate "H21 the first result of 0 is a new best" $TH 'final before = best[spec.category] ?? 0;' 'final before = best[spec.category] ?? -1;'
mutate "H22 an equal score is a new best" $TH "'isNewBest': result.score > before," "'isNewBest': result.score >= before,"
mutate "H23 the best is the latest score" $TH 'final bestScore = result.score > before ? result.score : before;' 'final bestScore = result.score;'
mutate "H24 the stored best is the latest score" $TH 'best[spec.category] = bestScore;' 'best[spec.category] = result.score;'
mutate "H25 every best is kept under one category" $TH 'best[spec.category] = bestScore;' "best['all'] = bestScore;"
mutate "H26 results are kept for the first user" $TH 'final best = _state(context, empty: empty).bestByUser[user.id]!;
      final before' "final best = _state(context, empty: empty).bestByUser['u-100']!;
      final before"
mutate "H27 the best list is of the first user" $TH 'final best = _state(context, empty: empty).bestByUser[user.id]!;
  final ids' "final best = _state(context, empty: empty).bestByUser['u-100']!;
  final ids"
mutate "H28 the best list is not sorted" $TH 'final ids = best.keys.toList()..sort();' 'final ids = best.keys.toList();'
mutate "H29 the claimed correct count is the answer count" $TH "'correct': result.correct," "'correct': result.answers.length,"
mutate "H30 the seeded all best is 871" $TH "'all': 870," "'all': 871,"
mutate "H31 the seeded characters best is 1341" $TH "'characters': 1340" "'characters': 1341"
mutate "H32 the empty set is seeded" $TH 'user.id: {if (!empty) ...?seededBest[user.id]},' 'user.id: {...?seededBest[user.id]},'
mutate "H33 the empty state is the default state" $TH 'final key = empty ? _emptyStateKey : _stateKey;' 'final key = empty && context.seed < 0 ? _emptyStateKey : _stateKey;'
mutate "H34 the all count is one short" $TH "? bank.length" "? bank.length - 1"
mutate "H35 a category count includes one more" $TH ': bank.where((q) => q.category == c.id).length,' ': bank.where((q) => q.category == c.id).length + 1,'
mutate "H36 the empty set lists categories" $TH '  if (empty) {
    return const MockResponse.ok' '  if (empty && request.query.isNotEmpty) {
    return const MockResponse.ok'
# H37 (the empty set having a bank) is equivalent: no route reaches the bank in the empty mode.
mutate "H38 the comics image is outside the art set" $TH "name: 'Comics', imageUrl: 'mock-asset://characters/011'" "name: 'Comics', imageUrl: 'mock-asset://characters/024'"
mutate "H39 the creators category is named Creator" $TH "name: 'Creators'" "name: 'Creator'"
mutate "H40 the round body reports another seed" $TH "'seed': seed," "'seed': seed + 1,"
mutate "H41 the server_error body differs" $TH "'Injected HTTP 500 for \${request.routeKey}'," "'Injected HTTP 501 for \${request.routeKey}',"
mutate "H42 the seed error names no parameter" $TH "{'parameter': 'seed'}" "{'parameter': 'seeds'}"
mutate "H43 the unknown-choice error has no choice id" $TH "'choiceId': choice," "'choiceId': 'x',"
# --- domain ------------------------------------------------------------------
mutate "D1 the best route is not in the manifest" $DOM "  'GET /v1/me/trivia/best',
];" '];'
mutate "D2 the slow scenario delays 1 s" $DOM 'const Duration triviaSlowDelay = Duration(seconds: 2);' 'const Duration triviaSlowDelay = Duration(seconds: 1);'
mutate "D3 the slow scenario fails with 500" $DOM 'rules: _rules(const FailureKind.slow(triviaSlowDelay)),' 'rules: _rules(const FailureKind.http(500)),'
mutate "D4 the server_error scenario fails with 503" $DOM 'rules: _rules(const FailureKind.http(500)),' 'rules: _rules(const FailureKind.http(503)),'
mutate "D5 the empty scenario is not empty" $DOM 'overrides: _handlers(empty: true),' 'overrides: _handlers(empty: false),'
mutate "D6 the empty set is not empty" $DOM '_register(router, _handlers(empty: true));' '_register(router, _handlers(empty: false));'
mutate "D7 the domain is named differently" $DOM "routeManifest = triviaRouteManifest;

  @override
  String get name => 'trivia';" "routeManifest = triviaRouteManifest;

  @override
  String get name => 'trivia2';"

echo
echo "TOTAL $total  KILLED $killed  SURVIVED $survived  BROKEN $broken"
if [[ ${#survivors[@]} -gt 0 ]]; then
  printf 'survivor: %s\n' "${survivors[@]}"
fi
[[ $survived -eq 0 && $broken -eq 0 ]]
