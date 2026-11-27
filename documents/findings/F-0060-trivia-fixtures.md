# F-0060: Trivia fixtures: a stateless round id, two seeds, and what the scoring spec had to pin down

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0060)
- **Type:** Design record / gotchas
- **Related:** T-0060, T-0051, T-0047, F-0047, F-0051, F-0050, plan 01 U47, P1-10, P1-23

## Summary
`mc_fixtures_editorial` (trivia slice) is the backend of the IX exemplar `trivia_quiz`. The decisions and traps below will matter to the exemplar's engine, its Scenario Outline and the later slices (news, glossary, help) of the same package.

1. **Two different seeds.** The *backend seed* (`MockBackend(seed:)`, default 42) decides which questions exist, because they are generated from `CharacterUniverse(seed)` and `ComicUniverse(seed)`. The *round seed* (`?seed=`) decides which 10 of them a round holds and in what order. P1-23 AC6 ("Given seed 42, a 10-question round scores deterministically") is the round seed on the default backend. Question ids (`q-<template>-<nn>`), counts, categories and time limits do not depend on the backend seed; question text and answers do.
2. **The round id carries the round.** `roundId = r-<category>-<difficulty>-<seed>`, and `POST results` rebuilds the round from it. There is no round state, so a round that was never requested can be scored, a round survives `reset()` in the sense that it is the same afterwards, and there is no "round expired" case to fake. The cost: a round id from backend seed A scored on backend seed B names different questions. The fixtures only ever run on one backend seed, so this is documented, not guarded.
3. **`correctChoiceId` is in the round body on purpose.** The task says the client's engine is tested against known rounds and that the server "recomputes the score": the client grades locally for instant feedback, and the server never reads a claimed score. A hidden-answer design would make the engine untestable offline.
4. **The streak follows the round's question order, not the order of the `answers` array.** The submission matches answers by `questionId`, so an array in any order must score the same. A mutant that scored in submitted order was only caught because a test submits the reversed array.
5. **A late correct answer is a timeout.** `choiceId` null or `elapsedMs >= limitMs` is a timeout, even when the choice is correct: 0 points and the streak resets. `limitMs - 1` still scores (bonus 0). The three boundary values are tests for every difficulty.
6. **Best per category, not per difficulty; `all` is a category.** `isNewBest` is `score > earlierBest` with an earlier best of 0 when none exists, so a first result of 0 is not a new best but the category is listed from then on.

## Design facts worth reusing
- **Scoring is written down as a table and read back from it.** `CONTRACT.md` has 17 worked examples as `| E1 | easy | `C0 W0x9` | 150 | 1 |` rows. `scoring_test.dart` parses the table, builds each answer list from the real round (`C` the correct choice, `W` a wrong one, `N` no choice) and checks the server and the oracle against the row. The doc, the oracle and the server cannot drift apart, and the IX Scenario Outline can copy the table unchanged.
- **The oracle shares no code with the fixture** and is written differently: the time bonus is found by counting up (the largest `b` in 0..50 with `b * limit <= 50 * remaining`), the streak by position in a run. 50 seeded rounds with random answers and timings (boundary values `limit - 1`, `limit`, `limit + 1` mixed in) agree with the server. The test also asserts the sample reached every outcome and a streak of at least 4, so it cannot pass vacuously.
- **A question's facts are not on the wire but are in the Dart API.** `TriviaQuestion.facts` (`{kind, characterId | comicId | seriesId, ...}`) lets the contract test check all 336 questions against `GET /v1/characters/:id`, `GET /v1/comics/:id`, `GET /v1/series/:id` and `GET /v1/comics?characterId=&orderBy=releaseDate` (the first appearance). A negative control flips the correct choice and adds a distractor that is also true; both must be reported.
- **Distractors are real values of the same type.** Years are within 4 of the truth, prices and page counts are other real values, powers and teams are drawn from the universe's own vocabulary, and characters, comics and creators are real names. None is also true (no "power of X" among X's powers, no comic that features X among the "first appeared in" distractors, no creator that holds the asked role).
- **Choice order is shuffled twice.** The bank gives each question a seeded order (so `c1` is not always the answer); the round shuffles again per round seed and question id. Over 1,000 rounds the correct choice sits at each position 24.6 to 25.4 % of the time (2496, 2536, 2505, 2463 of 10,000). A mutant with the second shuffle removed is killed by "one question is shown in several orders over 300 seeds".
- **Set and scenario of one name answer byte-identical bodies** (`trivia.empty`, `trivia.server_error`), as in F-0051. `trivia.slow` is a scenario only (a `FailureKind.slow` rule per route, 2 s).

## Traps
- **A tie on the first appearance.** `GET /v1/comics?characterId=X&orderBy=releaseDate` breaks a tie on the lower id; the bank must too. For backend seed 42 and 7 no selected character has a tie, so a tie-break mutant survived until the provider test also ran backend seed 4, where `q-character_first_comic-18` is a tie. Found by scanning seeds 0 to 39 for a question whose character has two comics on the earliest date.
- **The analyzer fails a build on warnings, so a mutant must not use a constant condition.** `if (x && false)` is a dead-code warning, which `Build did NOT complete` counts as broken, not killed. Mutants use conditions that are false in practice but not constant (`seen.length > 99`, `entry.length > 99`). A mutant that removes a null check must keep the type promotion the code below relies on (`?? 0` instead of dropping the `if`).
- **`MockResponse.error`'s `extra` is spread after `code`** (F-0051 §1): the extra fields here are `parameter`, `questionId`, `choiceId`, `expected`, never `code` or `message`.
- **`int` in JSON.** `elapsedMs: 5.0` reaches the handler as a `double` (the mock transport decodes the JSON text again), so "an integer" is checked with `is int`, and `1.5`, `"100"`, `true` and `null` are all `invalid_elapsed`.
- **`mutations.sh` needs a clean tree and a second output base** when it runs next to other Bazel work: it ran in a detached worktree (`git worktree add --detach`) with its own `--output_base`, so a flake check and the app wiring tests could use the main one. A full run of 123 mutants takes about 1 to 2 hours.
- **Two guards cannot be reached** and are excluded from the mutation list: `_sample`'s "pool too small" and `_template`'s "yielded only n questions" (both `StateError`s that guard a generation bug). They are the only uncovered lines (99.6 % line coverage, 454 of 456 lines).

## Decisions
- Added `invalid_body` (the body is malformed) and `unknown_choice` (a `choiceId` that is not one of the question's) to the list of typed codes in the task. A typo in a choice id would otherwise score as a wrong answer. Check order: body, round, count, question, duplicate, choice, elapsed.
- All three of `category`, `difficulty` and `seed` are required on `GET rounds`; a missing one is its typed error.
- `POST results` answers `200` (it evaluates a round, it does not create a resource with an id).
- `trivia.empty` has no categories at all (the list is empty and every category, `all` included, is `unknown_category`), so an empty state is reachable in the UI.
- The domain is registered in `appMockDomains` (`TriviaMockDomain`), with the `app_core` pubspec, BUILD and one test (`T-0060-AC5`).

## Review round (2026-11-27)
- **A missing `choiceId` key is `invalid_body`, not a timeout.** `{"questionId", "elapsedMs"}` and a wrong-case `choiceID` used to read as `choiceId == null`, so a client typo scored 0 silently. The key must be present; `null` is the explicit "no answer".
- **Cached questions are immutable.** The per-isolate bank hands the same `TriviaQuestion` objects to every request, so `choices` and `facts` are `List.unmodifiable` / `Map.unmodifiable`; a handler or test that mutated one would have corrupted every later round.
- **The `unknown_category` message follows the active set**: it lists `all, characters, comics, creators`, or says "there are no categories" under `trivia.empty`.
- **The gates script removes only what it created** (a `MADE` list, no unconditional `rm -rf`) and fails when a throwaway path already exists; it runs `test --lockfile_mode=error //...`.
