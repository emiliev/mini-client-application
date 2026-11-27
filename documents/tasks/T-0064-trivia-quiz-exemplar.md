# T-0064: `trivia_quiz` exemplar (IX archetype), P1-23

| Field | Value |
|---|---|
| Status | In Verification (handed off) |
| Owner | crew: Engineer (**Opus**: first IX exemplar, which the bricks copy; ADR-0011) |
| Verifier | crew: Verifier, **Opus tier** (exemplar) |
| Branch | `fleet/T-0064-trivia-quiz` |
| Created | 2026-11-27 |
| Depends on | T-0060 (`mc_fixtures_editorial` trivia and `CONTRACT.md` scoring), T-0059 (`mc_ds_charts`), T-0058 (`mc_ds_overlays`), T-0053/T-0056 (analytics, ADR-0012), T-0039/T-0050 (session epoch, `authPinned`), T-0052 (`mc_feature_flags`: the `trivia_hint` flag exists) |
| Related | plan 01 F092, P1-23 (EX-AC1–5; AC6: "Given seed 42, then a 10-question round scores deterministically; a Scenario Outline with the spec's scoring examples covers the engine through the flow (R6, no `test/unit/`)"), §6.1 (IX: 3 pages and 3 painters, 3 blocs and a pure-Dart engine, 3 endpoints, 2 nav methods); ADR-0007, ADR-0010, ADR-0011, ADR-0012; F-0056, F-0059, F-0060 |

## Goal
The seventh and last archetype exemplar, **interactive (IX)**: `feature/trivia/trivia_quiz`. You pick a category and a difficulty, then play a timed 10-question round. Each question has a countdown and 4 choices. You get instant feedback with a streak counter. At the end you see your score, a breakdown chart, and your best score.

The game rules live in a **pure-Dart engine inside the feature**. That engine must agree exactly with the server's scoring (`mc_fixtures_editorial` `CONTRACT.md`).

This package is the shape the P1-24 bricks copy for every IX feature (`trivia_daily`, `timelines_explorer` and others), so it must match the established exemplar shapes, with no workarounds.

## Scope
- **In: `feature/trivia/trivia_quiz`**
  - **Flow and navigator.**
    - `TriviaQuizFlow` has 3 pages: setup (category and difficulty), play, and results.
    - `TriviaQuizNavigator` has two methods:
      - `requestSignIn()`: the results page offers "Save your score" when signed out. On `true`, it posts the result for the new user.
      - `openComic(ComicId)`: a question's image or source links to the comic.
  - **Engine: pure Dart, no Flutter, no timers.** It is driven by injected time ticks.
    - Round state, answer and timeout handling, and the streak.
    - Scoring **exactly** as in `CONTRACT.md`, all in integer arithmetic.
    - The engine computes the score locally for instant feedback. The server's score from `POST /v1/me/trivia/results` is authoritative.
    - If the local and server scores differ, show the server's score and report the mismatch once to `mc_monitoring`.
  - **Blocs.**
    - One bloc each for setup (categories and best scores), play (it wraps the engine and the countdown, driven by an injected ticker), and results (the POST, best score, sign-in).
    - Each uses a freezed sealed state.
    - The session-epoch rule applies: check after every await, before a write. The results POST is pinned with `authPinned`.
  - **Timing.**
    - Use an injected clock and ticker, with fake time in tests.
    - When the app goes to the background, pause the countdown. When it returns, resume it. Use `AppLifecycleState` and document the rule.
    - When reduce motion is on (`MediaQuery.disableAnimations`), the countdown ring is not animated. Show the number only.
  - **Painters (3).**
    - A countdown ring (`CustomPainter` in the feature).
    - The results breakdown: an `McDonutChart` of correct, wrong and timeout, plus an `McBarChart` of points per question.
    - A streak flame or meter (`CustomPainter`).
    - Each one needs a recording-canvas test, as in F-0059.
  - **Flag.** When `trivia_hint` is on, the play page offers a 50/50 hint that hides 2 wrong choices once per round. The hint costs points. Define the rule. Because `CONTRACT.md` has no hint rule, the hint is client-only and the server must still agree: pick a design that keeps them consistent and document it. Examples: hide choices without changing scoring, or report the hint use and extend `CONTRACT.md`. If you need a fixture change, make it in `mc_fixtures_editorial` with its tests.
  - **Overlays.** Quitting mid-round asks via `showMcConfirm`.
  - **Analytics (ADR-0012).**
    - Events: `trivia_round_started`, `trivia_answer` (`correct`, `elapsed_bucket`) and `trivia_round_finished` (`score`).
    - Screens: `trivia_setup`, `trivia_play` and `trivia_results`.
  - **Tests and strings.**
    - l10n in en and de.
    - BDD, contract tests and goldens.
    - **No `test/unit/`** (R6): the engine is covered through the flow by Scenario Outlines.
- **In: `app/wiring/chronicle_wiring`.**
  - The `/trivia` route, nested under home, with `/trivia/play?category=&difficulty=&seed=` for deep links into a specific round.
  - `ChronicleRouteTargets` and the navigator implementation: the comic via `AppLocations` and sign-in.
  - `AppLocations.trivia` and `triviaPlay`, with a drift test.
- **In: `mini_client`.** A Trivia entry on home, and the deep link `miniclient://app/trivia`.
- **Out:** `trivia_daily`, leaderboards, sound and haptics, and `chronicle_sandbox` (a follow-up).

## Acceptance criteria
- **T-0064-AC1 (EX-AC1).** Given `trivia.default`, when I pick Characters / Easy and play, I see 10 questions in turn, each with 4 choices and a countdown. After the last answer the results show score, correct count and best. BDD.
- **T-0064-AC2 (EX-AC2).**
  - Given `server_error`: setup shows an error with Retry, and Retry recovers.
  - A failed results POST shows the local score with a "not saved, Retry" state, and Retry saves exactly once.
  - Given `trivia.empty`, setup shows the empty state.
  - BDD.
- **T-0064-AC3 (EX-AC3).**
  - Quit asks for confirmation. Cancel resumes, and the timer was paused while the dialog was open (document this rule). Confirm leaves.
  - Signed out, "Save your score" awaits `requestSignIn()`. On `true` the result posts for the new user only, pinned to the epoch. Run a held-response user switch in both orders.
  - `openComic` is called exactly once.
  - Wiring tests pass.
- **T-0064-AC4 (EX-AC4).**
  - `de` and `en_XA` at 1× and 2× text scale, with no overflow.
  - Goldens of all 3 pages and the 3 painters in 4 themes.
  - Reduce motion shows the static countdown.
- **T-0064-AC5 (EX-AC5).** E2E on your own simulator, with screenshots:
  - home → Trivia → setup → play a full round (tap answers; let one question time out) → results with charts;
  - the cold deep link `miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42` plays that exact round;
  - Back walks to home.
- **T-0064-AC6 (P1-23 AC6).**
  - Given seed 42, a 10-question round scores deterministically, and the engine's score equals the server's.
  - A **Scenario Outline whose Examples are the 17 worked examples in `mc_fixtures_editorial` `CONTRACT.md`** drives the engine through the flow, with fake time setting `elapsedMs`. Every row passes.
  - A mutation of each scoring rule is killed by the outline: bonus, streak, timeout boundary.
  - The countdown hits the timeout exactly at the limit, with limit − 1 / limit / limit + 1 under fake time.
  - Background and resume pauses and resumes the countdown.
- **T-0064-AC7 (architecture, codegen and gates).**
  - Architecture: `mc_arch_check` passes. The barrel exports only the flow, the navigator and arg types. The engine imports no Flutter, checked with a negative control.
  - Codegen: nothing generated is committed, and the output is byte-identical to build_runner's. The cutoff and fixtures checks pass. Globs use `MC_GENERATED_DART`. `T-0042-AC4_safety.sh` passes after `tool/ide_sync`.
  - Package coverage is ≥ 90 %.
  - `test --lockfile_mode=error //...`, lint, `rules_fork.sh check`, `l10n_check` and format (gated directories only) pass.
  - The 50-run flake check passes on every new target. This matters most for the timer tests.
  - Every evidence row names a test that exists at handoff.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27 (engineer): resumed after the usage-limit stop. The first worktree had been cleaned up with no commits on the branch (nothing lost) and no `mc-` simulator was left; a new worktree was made on `fleet/T-0064-trivia-quiz`.
- 2026-11-27 (engineer): **contract first** (`mc_fixtures_editorial`, `c8879ad`): the hint is a scoring rule the server applies (rule 4, `hintPenalty` 50, at most one per round, `too_many_hints`), 5 hint worked examples in their own table (the 17 scoring rows unchanged), and `comicId` on one-comic questions for `openComic`. Snapshots regenerated (3 round snapshots gain `comicId`; 2 new), validation, scoring and provider tests.
- 2026-11-27 (engineer): the feature (engine, 3 blocs, 3 pages, 2 painters, charts, l10n) and its BDD (`94beedd`); contract, scope, painter, golden and architecture tests (`c8d5d4a`); the wiring, home entry, app tests and 2 e2e targets (`2b8f058`). E2E 2/2 on `mc-T-0064-engineer-68050` (deleted).
- 2026-11-27 (engineer): first mutation pass: S01 (the engine's `>=` limit boundary) **survived**: through the flow the countdown's own timer always ended the question first, so the engine's judge never saw an answer at the limit. Fixed in the test harness, not by weakening anything: a tap at or past the limit is played one millisecond before the timer with the quiz's clock moved ahead (a late timer callback), so the outline's `C20000`/`C20001` rows are sent and judged exactly as the contract writes them (F-0064 §5.3). Added P13 (the timer itself a millisecond late).
- 2026-11-27 (engineer): a linked round without a seed drew it in the flow's `build` (once per rebuild); it is now drawn once by the play bloc, and a Retry plays the same round (`flow_scope_test`).
- 2026-11-27 (engineer): merged `origin/main` (T-0062; no conflicts); the gates use T-0062's shared format gate.
