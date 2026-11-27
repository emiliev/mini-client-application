# Editorial contract: trivia (`mc_fixtures_editorial`)

Our own domain-first contract (F-0003): timed multiple-choice trivia rounds about the Marvel-style universe of `mc_fixtures_characters` and `mc_fixtures_comics`, for the quiz feature (`trivia_quiz`, plan 01 F092). It claims no compatibility with any real API. Content is invented. This package will also hold news, glossary and help later (T-0060 is the trivia slice only).

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. The domain name is `trivia`.

The domain owns no facts: every question is generated from `CharacterUniverse(seed)` and `ComicUniverse(seed)`, where `seed` is the **backend's** seed (default 42), so each answer is true on `GET /v1/characters/:id`, `GET /v1/comics/:id` and `GET /v1/series/:id` of the same backend. Two seeds are involved, and they are different things:

- the **backend seed** (`MockBackend(seed:)`) decides which questions exist;
- the **round seed** (`?seed=`) decides which of them a round holds and in what order.

## Auth

`GET /v1/trivia/categories` and `GET /v1/trivia/rounds` are public. `POST /v1/me/trivia/results` and `GET /v1/me/trivia/best` need `Authorization: Bearer <access token>`, checked with `mc_fixtures_identity`'s own `userForAuthorization` (the same rule as `GET /v1/me`). A missing, malformed or expired token, a refresh token used as a bearer, a token of an unknown user or a scheme other than `Bearer` is `401` `unauthenticated`. Auth is checked first, before the body. A test can mint a token without signing in: `mintAccessToken('u-100', 1)`.

Best scores belong to the user who earned them: one user's results are never visible to another.

## Routes

| Route | Auth | Purpose |
|---|---|---|
| `GET /v1/trivia/categories` | none | The categories and how many questions each holds |
| `GET /v1/trivia/rounds` | none | One round of 10 questions |
| `POST /v1/me/trivia/results` | bearer | Score a finished round, keep the best |
| `GET /v1/me/trivia/best` | bearer | The user's best score per category |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `GET /v1/trivia/categories`

`200` `{"categories": [<category>, ...]}`, always in this order: `all`, `characters`, `comics`, `creators`.

```json
{"id": "comics", "name": "Comics", "questionCount": 144, "imageUrl": "mock-asset://characters/011"}
```

`all` has the count of every question (336 on every seed). `imageUrl` is a bundled `mock-asset://characters/NNN` placeholder.

### `GET /v1/trivia/rounds?category=<id>&difficulty=<d>&seed=<n>`

All three parameters are required. `category` is `all` or a category id; `difficulty` is `easy`, `medium` or `hard`; `seed` is the round seed (see Validation).

`200`:

```json
{
  "roundId": "r-all-easy-42",
  "category": "all",
  "difficulty": "easy",
  "seed": 42,
  "questions": [
    {
      "id": "q-comic_price-07",
      "category": "comics",
      "difficulty": "easy",
      "prompt": "What was the cover price of Slate Crossing #1?",
      "choices": [{"id": "c3", "text": "$4.99"}, {"id": "c1", "text": "$2.99"}, {"id": "c4", "text": "$5.99"}, {"id": "c2", "text": "$3.99"}],
      "correctChoiceId": "c1",
      "timeLimitSeconds": 20,
      "imageUrl": "mock-asset://characters/020"
    }
  ]
}
```

- **Exactly 10 questions**, all of the requested difficulty, no question twice, drawn from the category (`all` draws from every category).
- **Deterministic.** The same backend seed, `category`, `difficulty` and `seed` give a byte-identical body. Different round seeds give different rounds (for the shipped bank, seeds 42 and 43 differ). The question order and the choice order both follow from the round seed alone.
- **Exactly 4 choices**, ids `c1` to `c4`, texts distinct and of the same type as the correct one. The ids are fixed per question; their **position** in the list is shuffled per round, so the correct choice is at each position about a quarter of the time. Exactly one choice is `correctChoiceId`.
- `correctChoiceId` is in the body on purpose: the client's engine grades locally for instant feedback. The server never trusts it: `POST results` recomputes the score.
- `imageUrl` is optional (absent on questions with no picture).
- `timeLimitSeconds` is per question, by difficulty:

| Difficulty | `timeLimitSeconds` | Limit in ms |
|---|---|---|
| `easy` | 20 | 20000 |
| `medium` | 15 | 15000 |
| `hard` | 10 | 10000 |

- **`roundId`** is `r-<category>-<difficulty>-<seed>`. The server keeps no round state: the id names the round, and `POST results` rebuilds the round from it. So a round that was never requested can still be scored.

### The question bank

336 questions per backend seed: 14 templates of 24 questions each. Question ids are `q-<template>-<nn>` (`nn` 01 to 24). The questions of a seed are a pure function of the seed; every round of a category and difficulty is drawn from the pool below.

| Template | Category | Difficulty | Question | Truth source |
|---|---|---|---|---|
| `character_team` | characters | easy | Which team does X belong to? | `team` on `GET /v1/characters/:id` |
| `character_power` | characters | medium | Which of these is a power of X? | `powers` on the same |
| `character_debut_year` | characters | medium | In which year did X first appear? | `firstAppearanceYear` |
| `character_first_comic` | characters | hard | In which comic did X first appear? | the earliest `releaseDate` (ties: lower id) of `GET /v1/comics?characterId=X` |
| `character_debut` | characters | hard | Which of these characters first appeared in Y? | `firstAppearanceYear` of the correct one is Y, of the others it is not |
| `comic_cast` | comics | easy | Which character appears in C? | `characters` on `GET /v1/comics/:id` |
| `comic_price` | comics | easy | What was the cover price of C? | `price.amountCents` |
| `comic_year` | comics | medium | In which year was C released? | `releaseDate` |
| `series_start` | comics | medium | In which year did the series S begin? | `startYear` on `GET /v1/series/:id` |
| `comic_pages` | comics | hard | How many pages does C have? | `pageCount` |
| `series_end` | comics | hard | In which year did the series S end? | `endYear` |
| `creator_writer` | creators | easy | Who wrote C? | the `writer` credit on `GET /v1/comics/:id` |
| `creator_penciller` | creators | medium | Who penciled C? | the `penciller` credit |
| `creator_inker` | creators | hard | Who inked C? | the `inker` credit |

Every (category, difficulty) pair holds at least 24 questions, so a round never runs short. The wrong choices are plausible: years are within four of the true one, prices and page counts are other real values, names are other characters, creators, comics or teams, and none is also true (a "power of X" is never one of X's three powers, a "comic with X" never features X).

## Scoring

The server recomputes the score of every submitted round. The feature's engine must give the same numbers. All arithmetic is in **integers**; there is no floating point and no rounding other than integer division.

Let `limitMs` be the question's `timeLimitSeconds * 1000`. Answers are scored **in the order of the round's `questions`** (the order of `GET rounds`), whatever the order of the submitted `answers` array. For each question in that order:

1. **Timeout.** If `choiceId` is `null`, or `elapsedMs >= limitMs`, the answer is a timeout: `0` points, and the streak is reset to 0. (`elapsedMs == limitMs` is a timeout; `limitMs - 1` is not. A timeout is a timeout even if `choiceId` names the correct choice.)
2. **Wrong.** Otherwise, if `choiceId` is not `correctChoiceId`: `0` points, and the streak is reset to 0.
3. **Correct.** Otherwise the streak grows by 1 (it was the number of correct answers in a row just before this one), and the answer is worth

   `100 + timeBonus + streakBonus`

   - `timeBonus = (50 * (limitMs - elapsedMs)) ~/ limitMs` (integer division, so it is the floor; `50` at 0 ms, `0` at `limitMs - 1`),
   - `streakBonus = 25 * (streak - 1)` (so the first correct answer of a run gets 0, the second 25, the third 50, and so on; there is no cap).

`score` is the sum over the 10 answers. `correct` is the number of answers that were correct (not wrong, not timed out). The most a round can score is 2625 (ten correct answers at 0 ms: `10 * 150 + 25 * (0 + 1 + ... + 9)`).

### Worked examples

In `Answers`, `C<ms>` is the correct choice at `<ms>` of elapsed time, `W<ms>` a wrong choice (not the correct one), `N<ms>` no choice (`choiceId: null`), and `x<n>` repeats the answer `<n>` times. The ten answers are for the ten questions in round order. Round: `category=all`, `seed=42`, the given difficulty (rounds are the same shape for any seed). A test builds each row from the real round and checks the server's `score` and `correct`; the Scenario Outline of the feature copies this table.

| ID | Difficulty | Answers | Score | Correct | Why |
|---|---|---|---|---|---|
| E1 | easy | `C0 W0x9` | 150 | 1 | 100 + 50 at 0 ms |
| E2 | easy | `C5000 W0x9` | 137 | 1 | 100 + 50*15000/20000 = 37.5, floor 37 |
| E3 | easy | `C10000 W0x9` | 125 | 1 | 100 + 25 (exact) |
| E4 | easy | `C19999 W0x9` | 100 | 1 | 1 ms left: 50*1/20000 = 0 |
| E5 | easy | `C20000 W0x9` | 0 | 0 | `elapsedMs` equals the limit: timeout |
| E6 | easy | `C20001 W0x9` | 0 | 0 | past the limit: timeout |
| E7 | medium | `C7000 W0x9` | 126 | 1 | 100 + 50*8000/15000 = 26.67, floor 26 |
| E8 | hard | `C3333 W0x9` | 133 | 1 | 100 + 50*6667/10000 = 33.335, floor 33 |
| E9 | easy | `W0x10` | 0 | 0 | all wrong |
| E10 | easy | `N0x10` | 0 | 0 | no answer is 0 even at 0 ms |
| E11 | easy | `C0 C0 W0x8` | 325 | 2 | 150, then 150 + 25 |
| E12 | easy | `C0 C0 C0 W0 C0 C0 N0 C0 C0 C0` | 1375 | 8 | runs of 3, 2, 3: (150+175+200) + (150+175) + (150+175+200); wrong and no-answer reset the streak |
| E13 | easy | `C0x10` | 2625 | 10 | the maximum |
| E14 | hard | `C1000 C2000 C3000 W0x7` | 495 | 3 | 145 + (140+25) + (135+50) |
| E15 | medium | `C14999x10` | 2125 | 10 | no time bonus; 10 * 100 + 1125 |
| E16 | easy | `C0 C20000 C0 C0 W0x6` | 475 | 3 | a late correct answer is a timeout and resets the streak: 150 + 0 + 150 + 175 |
| E17 | easy | `C0 C0 W19999 C0 W0x6` | 475 | 3 | a wrong answer just inside the limit resets the streak: 150 + 175 + 0 + 150 |

An answer's points are also in the response `breakdown`.

## `POST /v1/me/trivia/results`

Body `{"roundId": "r-all-easy-42", "answers": [{"questionId": "q-comic_price-07", "choiceId": "c2", "elapsedMs": 4200}, ...]}`. `choiceId` is a choice id or `null`; `elapsedMs` is the time in whole milliseconds. Exactly one answer per question of the round, in any order.

`200`:

```json
{
  "roundId": "r-all-easy-42",
  "category": "all",
  "score": 1375,
  "correct": 8,
  "bestScore": 1375,
  "isNewBest": true,
  "breakdown": [{"questionId": "q-comic_price-07", "outcome": "correct", "points": 150}, ...]
}
```

- `breakdown` has one entry per question in round order; `outcome` is `correct`, `wrong` or `timeout`; the points add up to `score`.
- The claimed score of a client is never read: only the answers count.
- **Best scores.** The best is kept per user and per **category** (the round's category, so `all` is its own entry; difficulty does not matter). `bestScore` is the larger of this score and the user's earlier best for the category (0 when there was none). `isNewBest` is true **only** when this score is strictly higher than that earlier best (a score of 0, or a tie, is never a new best). Every submitted round makes the category appear in `GET best`, even with a score of 0. A rejected request changes nothing. Bests persist until `reset()`.

## `GET /v1/me/trivia/best`

`200` `{"best": [{"category": "all", "bestScore": 870}, ...]}`, only the categories the user has a result for, sorted by category id. The default set starts `u-100` with `all` 870 and `characters` 1340, and `u-101` with none.

## Validation

All failures are `400` with `{"error": {"code", "message", "parameter", ...}}`. The first failing check is the answer.

`GET rounds`, in order:

| Order | `error.code` | Rule | Extra fields |
|---|---|---|---|
| 1 | `unknown_category` | `category` missing, or not `all` / `characters` / `comics` / `creators` (case-sensitive). The message lists the active categories, or says there are none (`trivia.empty`) | `parameter: "category"` |
| 2 | `invalid_difficulty` | `difficulty` missing, or not exactly `easy`, `medium` or `hard` | `parameter: "difficulty"` |
| 3 | `invalid_seed` | `seed` missing, or not a canonical decimal integer from 0 to 2147483647 (2^31 - 1): no sign, no spaces, no leading zeros (`0` is fine, `007`, `+5`, `-1`, `4.5` and `2147483648` are not) | `parameter: "seed"` |

`POST results`, after the auth check:

| Order | `error.code` | Rule | Extra fields |
|---|---|---|---|
| 0 | `invalid_body` | The body is not an object with a `roundId` string and an `answers` list of objects that each hold a `questionId` string and a `choiceId` **key** whose value is a string or `null` (an answer with no `choiceId` key, or with `choiceID`, is rejected, never read as a timeout) | `parameter: "body"` |
| 1 | `unknown_round` | `roundId` is not `r-<category>-<difficulty>-<seed>` of a known category, a difficulty and a valid seed (canonical form) | `parameter: "roundId"` |
| 2 | `answer_count_mismatch` | The number of answers is not 10 | `parameter`, `expected: 10` |
| 3 | `unknown_question` | A `questionId` is not a question of this round (the first one is named) | `parameter`, `questionId` |
| 4 | `duplicate_answer` | A `questionId` appears twice (the first repeated one is named) | `parameter`, `questionId` |
| 5 | `unknown_choice` | A `choiceId` is not one of that question's choice ids (not in the original list of codes; added so a typo cannot pass as a wrong answer) | `parameter`, `questionId`, `choiceId` |
| 6 | `invalid_elapsed` | `elapsedMs` is missing, not an integer, or negative (also for an answer whose `choiceId` is `null`) | `parameter`, `questionId` |

Checks 3 to 6 each look at all answers before the next one starts, so with 10 answers and no unknown or repeated question, every question is answered exactly once. A rejected write changes nothing.

### Other errors

| Status | `error.code` | When |
|---|---|---|
| 401 | `unauthenticated` | See Auth |
| 404 | `not_found` | No mock route (the body names the path) |
| 500 | `handler_error` | A handler threw |
| any | `injected_failure` | A `FailureRule` of kind `http(status)`; also the body of the `server_error` set |

## Test-facing facts (default set, backend seed 42)

| Fact | Value |
|---|---|
| Questions | 336: 120 `characters`, 144 `comics`, 72 `creators` |
| Per (category, difficulty) | `characters`: easy 24, medium 48, hard 48; `comics`: easy 48, medium 48, hard 48; `creators`: 24 each; `all`: easy 96, medium 120, hard 120 |
| Seeded bests | `u-100`: `all` 870, `characters` 1340; `u-101`: none |
| Max score | 2625 |
| Depends on the backend seed | the questions (their text and answers); not their ids, the categories, the counts or the time limits |

## Scenarios

| Name | Effect |
|---|---|
| `trivia.empty` | No categories (the list is empty), `rounds` answers `unknown_category` for every category (even `all`), `results` answers `unknown_round` for every round, `best` is an empty list. Auth and the other validation are unchanged. Has its own state, so it is empty even after the default set was used |
| `trivia.server_error` | Every route fails with `500` (`injected_failure`) |
| `trivia.slow` | Every route answers normally after an extra 2 seconds (`triviaSlowDelay`), so a request with a shorter receive timeout times out |

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `editorialFixtureSets`. A test registers them once (`editorialFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario. Each set serves all four routes. The set and the scenario of the same name answer the same bodies. The `trivia.default` set is meant to be served with the comics and characters sets of the same backend seed, so a question's facts resolve on their endpoints; it needs the identity set that issues the token.

| Set | Cast | Test-facing facts |
|---|---|---|
| `trivia.default` | `TriviaMockDomain` | See the table above |
| `trivia.empty` | `EmptyTriviaDomain` | as the `trivia.empty` scenario; no scenarios |
| `trivia.server_error` | `FailingTriviaDomain` | all four routes answer `500` with `error.code` `injected_failure`, the same body as the scenario (whatever the auth); no scenarios |

`trivia.slow` is a scenario only.

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `requestBody`, `status`, `body`), run on a fresh default backend. A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_editorial/tool/update_snapshots.dart`, review it, and update this file.
