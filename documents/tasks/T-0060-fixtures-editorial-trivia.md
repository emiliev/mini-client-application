# T-0060: `mc_fixtures_editorial`, the trivia slice (U47, P1-10 subset)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (fixtures; ADR-0011) |
| Branch | `fleet/T-0060-fixtures-editorial-trivia` |
| Created | 2026-11-27 |
| Depends on | T-0038 (`mc_fixtures_comics`), T-0039 (`mc_fixtures_identity`, `userForAuthorization`), the conventions of T-0043, T-0047 and T-0051 |
| Related | plan 01 U47, P1-10, P1-23 (IX exemplar `trivia_quiz`: AC6 "Given seed 42, then a 10-question round scores deterministically"), F092; ADR-0005; F-0047, F-0051 |

## Goal
The backend for the IX exemplar `trivia_quiz` (P1-23). The quiz takes timed multiple-choice rounds about the Marvel universe. Each round is deterministic per seed, so the scoring engine in the feature can be tested against known rounds.

## Scope
- **In: `utility/mc_fixtures_editorial` (UM, pure Dart), trivia only.**
  - **Question bank.** At least 120 questions generated from the characters and comics fixtures' public APIs. Examples: "Which character first appeared in <comic>?", "Who created <comic>?", "In which year did <comic> come out?". Hand-written questions are allowed too.
    - Each question has an `id`, `category`, `difficulty` (`easy`, `medium` or `hard`), `prompt`, exactly 4 `choices` (ids and text), the `correctChoiceId`, and an optional `imageUrl` that resolves to a bundled asset.
    - The 3 wrong choices are plausible: they have the same type as the correct one and are all distinct.
  - **Routes.**
    - `GET /v1/trivia/categories`: id, name, question count and an image.
    - `GET /v1/trivia/rounds?category=<id>&difficulty=<d>&seed=<n>`: a round of exactly 10 questions with no repeats, plus a `roundId` and a `timeLimitSeconds` per question (by difficulty).
      - The same `category`, `difficulty` and `seed` give a byte-identical round.
      - Choice order is shuffled deterministically from the seed.
      - `category=all` is allowed.
    - `POST /v1/me/trivia/results`: `{roundId, answers: [{questionId, choiceId|null, elapsedMs}]}`. It needs a bearer.
      - The server **recomputes the score** with the documented rules (below) and returns `{score, correct, bestScore, isNewBest}`.
      - It keeps the best score per user and category until `reset()`.
      - The client's claimed score is never trusted.
    - `GET /v1/me/trivia/best`: the best score per category for the user.
  - **Scoring rules** (in `CONTRACT.md`, so the feature's engine and the fixture agree):
    - A correct answer is worth 100 points, plus a time bonus of `floor(50 × remainingMs / limitMs)`.
    - A wrong answer or a timeout (`choiceId` null, or `elapsedMs` ≥ the limit) is worth 0.
    - There is a streak bonus of +25 for each consecutive correct answer after the first.
    - All arithmetic is in integers.
    - Write at least 8 worked examples. They are the spec for the IX exemplar's Scenario Outline.
  - **Validation.** Errors are 400 with a typed code:
    - `unknown_category`
    - `invalid_difficulty`
    - `invalid_seed` (outside 0–2^31−1, or not an integer)
    - `unknown_round`
    - `answer_count_mismatch`
    - `unknown_question`
    - `duplicate_answer`
    - `invalid_elapsed` (negative)

    A request without a valid bearer gets 401. One user's results are never visible to another.
  - **Sets and scenarios.** The `default`, `empty` and `server_error` sets and scenarios have one identical body each. `trivia.slow` adds latency. Add a `CONTRACT.md`. Register the domain in `appMockDomains`.
- **Out:** leaderboards (community, U46), news, glossary, help.

## Acceptance criteria
- **T-0060-AC1:** Determinism.
  - The same requests for seed 42 give byte-identical bodies.
  - Rounds for seeds 42 and 43 differ.
  - A round never repeats a question.
  - The 4 choices are distinct and exactly one is correct.
  - Over 1,000 seeded rounds, every position of the correct choice (0–3) appears 20–30 % of the time.
- **T-0060-AC2:** Scoring.
  - Every worked example in `CONTRACT.md` is a test.
  - An independent oracle in the test, not the fixture's code, agrees with the server for 50 seeded rounds with randomised answers and timings.
  - Mutations to the bonus, the streak and the timeout boundary (`elapsedMs` = limit − 1, = limit, = limit + 1) are killed.
- **T-0060-AC3:** Validation and auth.
  - Every typed code is pinned.
  - 401 is returned without a bearer and with an expired one.
  - Results are per user and persist until `reset()`.
  - `isNewBest` is true only on a strictly higher score.
- **T-0060-AC4:** Contract.
  - The snapshots match.
  - Every generated question's facts agree with the characters and comics endpoints: the creator, year and first appearance are checked against `GET /v1/comics/{id}` and the character's endpoint.
  - Images resolve to bundled assets.
- **T-0060-AC5:** Packaging and gates.
  - The package is pure Dart (closure check with a negative control), registered, and passes the fixtures check. Coverage is ≥ 90 %.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check` and format pass. Run format on the gated directories only (P-111).
  - The 50-run flake check passes on the new targets.

## Log
- 2026-11-27: Created and dispatched (TL).
