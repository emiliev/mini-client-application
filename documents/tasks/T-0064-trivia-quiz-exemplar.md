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
- PO 2026-11-27: no feature goldens (ADR to follow). Relayed by the TL during the handoff: the golden test and its 29 goldens are deleted (none had been merged), AC4's visual checks are the widget tests that already existed (German strings, no overflow at 2x in German and the pseudo-locale, the static countdown with reduce motion), and the painters' recording-canvas tests now run the ring and the streak meter in each of the 4 themes. The AC4 text above still names goldens; this entry supersedes it.
- 2026-11-27 (engineer): ADR-0015 (lean verification, merged from `origin/main`, amended at `d65c36e`). Plain unit tests of the pure engine are now allowed: `:engine_test` (5) covers the hint's choice of what to hide and the engine's refusals; the architecture check lets `test/unit/` import the engine and its model only (the "no `test/unit/`" assertion is replaced, as ADR-0015 relaxes R6). The mutation script runs the 15 targeted mutants by default (`MC_ALL=1` for the full list); the full pass already run is kept as evidence. No Verifier pass follows (`/code-review`, a fix round, the TL's gates), so this Outcome is the evidence.

## Outcome
**Handed off** for review and verification on `fleet/T-0064-trivia-quiz`. Finding: [F-0064](../findings/F-0064-interactive-exemplar.md) (the rules the IX bricks copy). ADR draft: [ADR-0014](../adr/0014-interactive-engine-and-injected-time.md) (Proposed: where an IX engine lives and how time reaches it). Evidence: [`documents/evidence/T-0064/engineer/`](../evidence/T-0064/engineer/).

### What was built
- **`feature/trivia/trivia_quiz`** (IX), in plan 01 §3.3's layout and the earlier exemplars' shapes:
  - **Barrel:** `TriviaQuizFlow`, `TriviaQuizNavigator`, `ComicId` (R4).
  - **Navigator (the archetype's 2):** `openComic(ComicId)` (a question's comic, from the results) and `requestSignIn()` (Save your score).
  - **Flow:** `TriviaQuizFlow(navigator:, clock:, nextSeed:, category:, difficulty:, seed:)`. Pages `trivia_setup`, `trivia_play`, `trivia_results`; the results replace the play page. Opened at a round (`category` and `difficulty` given) it has no setup page and leaving the round leaves the flow.
  - **Engine (pure Dart, ADR-0014):** `domain/engine/scoring.dart` (`judge`, `pointsFor`, the contract's constants) and `trivia_engine.dart` (round state, answer/timeout, streak, the once-per-round 50/50 hint, deterministic choice of what the hint hides). No Flutter, timers, clock or floating point.
  - **Time:** `TriviaTicker` (the injected monotonic clock and `Timer`s), `QuestionClock` (start, pause, resume). A 100 ms frame tick and a one-shot timer at the limit. Pauses: background (anything but `resumed`), covered (`FlowScope.outerIsCurrent`), the quit dialog.
  - **Data:** retrofit `TriviaQuizApi` (`GET v1/trivia/categories`, `GET v1/trivia/rounds`, `POST v1/me/trivia/results` pinned, `GET v1/me/trivia/best` pinned); 11 DTOs (`@Freezed(fromJson: true, toJson: true)`, R30); domain models; a stateless repository.
  - **Blocs (3):** setup (categories, best per category following the session), play (engine + countdown), results (the POST, sign-in, the server's score wins, mismatch reported once, the comic). Freezed sealed states; every await is a session boundary; no `add` after close.
  - **Painters:** a countdown ring and a streak meter (`CustomPainter`), and the results breakdown (`McDonutChart` of outcomes, `McBarChart` of points per question).
  - **Flag:** the `trivia_hint` experiment (variant `hint`), read once per round.
  - **Analytics (ADR-0012):** `trivia_round_started` (`category`, `difficulty`), `trivia_answer` (`correct`, `elapsed_bucket` q1..q4 or timeout), `trivia_round_finished` (`score`); screens `trivia_setup`, `trivia_play`, `trivia_results`.
  - **l10n:** en, de, en_XA (53 keys).
  - **Tests (ADR-0015: BDD first, plain unit tests for the engine, no goldens):** 4 `.feature` files (68 BDD tests with the outline rows), `contract_test` (10), `flow_scope_test` (11 with the loop), `painter_test` (10: the ring and the meter in each of the 4 themes, the theme colours, the breakdown), `architecture_test` (6), `outline_matches_contract_test` (3), `engine_test` (5).
- **`app/wiring/chronicle_wiring`** (was a skeleton): `trivia_routes.dart` (`TriviaRoute` `/trivia` `trivia_setup`, child `TriviaPlayRoute` `play?category=&difficulty=&seed=` `trivia_play`), `ChronicleRouteTargets` + impl, `TriviaQuizNavigatorImpl` (comic via `AppLocations`, the shared fixture sign-in sheet "to save your score"), `ChronicleWiringDIInitializer` with `chronicleClock` (a `Stopwatch`) and `chronicleSeed`, `routes_test` (10).
- **`app/wiring/app_core`:** `AppLocations.trivia`, `AppLocations.triviaPlay(...)`.
- **`app/mini_client`:** a Trivia entry on home (last, so the entries above keep their place); `trivia_route_test` (3); `analytics_screens_test` gains the 2 route names and 2 screen-order tests; e2e `trivia_journey_test`, `trivia_deeplink_test`.
- **`utility/mc_fixtures_editorial`** (the hint rule and `comicId`, §"Hint design" below).

### AC → evidence
| AC | Tests and evidence |
|---|---|
| AC1 | `:bdd_test` "Characters / Easy: ten questions in turn, then the results with the score, the correct count and the best" (the ten prompts are the fixture round's in order, each shown with four choices and 20 s; 9 correct; the score is what the server makes of the POST body; it is the reader's new best on the backend; one POST with the reader's bearer; no error); "Signed out, the setup shows no best and asks the server for none"; "Back from the results, the setup shows the new best"; "Play again starts a new round of the same category and difficulty"; "The best scores follow the session"; "A best-score answer for a session that is gone is read again for the current one"; "A user switch right before the best scores are sent sends nothing under the old user"; "A double tap on Start opens one round"; "A failed read of the best scores keeps the categories usable"; `:flow_scope_test` "a setup built under another screen loads nothing until it is shown, then once; covered and shown again it reads no categories again" |
| AC2 | `:bdd_test` "The categories fail, and Retry recovers" (`trivia.server_error`); "With no categories, the setup shows the empty state" (`trivia.empty`); "The round fails to load, and Retry plays it"; "A failed save shows the local score, not saved, and Retry saves exactly once" (double-tapped Retry: 2 POSTs in all, the failed one and one save; best 870 unchanged, no "New best!") |
| AC3 | `:bdd_test` "Quitting asks first, and Confirm goes back to the setup"; "Opened at a round, confirming quit leaves the quiz"; "Quitting while the round loads leaves at once, with no dialog"; `trivia_quiz_timer.feature` "The countdown stops while the quit dialog is open, and Cancel resumes the round" (60 s under the dialog, then `Correct! +125` at 5 + 5 s). Sign-in: "Signed out, Save your score asks to sign in and saves for that user" (1 POST, collector's bearer); "Signed out, backing out of signing in saves nothing"; "Signed out, a sign-in elsewhere and then backing out of the sheet saves nothing"; "Signed out, a sign-in answer of yes with nobody signed in saves nothing". **Held-response user switch, both orders:** "A user switch while the result is on its way drops the answer, and Retry saves for the new user" and "A user switch right before the result is sent sends nothing under the old user, and Retry saves for the new one" (0 POSTs reach the backend, then 1 with the collector's bearer; the reader's best unchanged). "A question about a comic opens it once, even on a double tap". `chronicle_wiring:routes_test` (10: both routes, the link forms, openComic pushes the comic, requestSignIn signed in and out, the initializer, the clock and seeds, the drift table); `mini_client:trivia_route_test` "a comic of the results opens its page, and Back returns to the results" |
| AC4 | `trivia_quiz_l10n.feature` "In German at <scale>x every page reads German and nothing overflows" (1x, 2x: German setup, question, feedback, results), "In the pseudo-locale at <scale>x nothing overflows on any page" (1x, 2x), "In German the quit dialog reads German". Reduce motion: `trivia_quiz_timer.feature` "With reduce motion the countdown is the number only" and "Without reduce motion the countdown is a ring around the number". The painters on a recording canvas (no goldens, PO 2026-11-27), `:painter_test`: "the countdown ring in <theme>: a full turn at the start, the share left after 5 s, urgent at a quarter, no arc at the end" and "the streak meter in <theme> lights one pill per correct answer in a row, and none after a miss" for light, dark, highContrast and highContrastDark; "the four themes draw the ring and the meter in their own colours"; "the results breakdown: one donut arc per outcome in proportion, and the points per question as bars". `l10n_check:workspace_gate_test` |
| AC5 | e2e on a fresh `mc-T-0064-engineer-*` (iOS 26.2, deleted), [summary](../evidence/T-0064/engineer/e2e/e2e-summary.md): `trivia_journey_test` 60–66 (home → Trivia → setup Characters / Hard → a full round tapped, question 4 left to time out → results with the donut and bars), `trivia_deeplink_test` 67–68c (`miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42` cold: every prompt equals the backend's round for those values, 10 of 10 correct, then Back → setup → home). After merging `origin/main` (T-0062: the new bundle id and e2e script), on another fresh simulator (deleted): [3/3 PASS](../evidence/T-0064/engineer/e2e_after_merge/e2e-summary.md), the two trivia targets and `store_journey_test` as a regression check, with no build-failure marker. Also `mini_client:trivia_route_test` (the home entry, the cold link's back stack), `chronicle_wiring:routes_test`, `:flow_scope_test` "a linked round without a seed draws one from the seed source, once: a Retry plays the same round" |
| AC6 | `:engine_test` "it keeps the correct choice and one wrong one, the same one every time, and that one depends on the round and question", "it hides two wrong choices of the question asked, once per round; a hidden choice cannot be answered", "a timeout is no choice at the limit, resets the streak, and the round finishes after its last question". `trivia_quiz_scoring.feature` "<id>: the answers <answers> on <difficulty> score <score> with <correct> correct, locally and on the server": **the 17 CONTRACT.md rows verbatim** (E1–E17; the engine's score while the POST is held, the server's after, the POST body as the row says, no mismatch); "<id>: with the 50/50 hint, the answers <answers> on <difficulty> score <score>, locally and on the server" (H1–H5); "Seed 42 gives the same round every time, and the engine's score is the server's"; "When the server's score differs from the engine's, the server's is shown and the mismatch is reported once". `:outline_matches_contract_test` (the two tables are the same rows; negative controls). Timers: "On <difficulty> the question times out at <limit> ms, not one millisecond before" (limit − 1 open, limit timed out, all 3 difficulties), "On <difficulty> a millisecond past the limit the question has timed out", "In the background (<state>) the countdown stops, and it resumes where it stopped" (inactive, hidden, paused), "Time in the background does not count towards an answer"; `:flow_scope_test` "a round covered by another screen stops its countdown, and it goes on when the round is shown again". Hint: "With the hint experiment on, the 50/50 hint hides two wrong choices once per round", "Without the hint experiment there is no hint", `:flow_scope_test` "the hint experiment is read once per round". Rule mutants killed by the outline: S01 (timeout boundary), S03–S05, S07, S08 (bonus, streak), S06, S09 (hint) |
| AC7 | [`T-0064-AC7_gates.md`](../evidence/T-0064/engineer/T-0064-AC7_gates.md) **PASS** on the merge with `origin/main`: `test --lockfile_mode=error //...` 210/210 (touched packages uncached), `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, the shared format gate, `l10n_check`, fixtures check, relative paths; [byte identity, 14 of 14 EQUAL](../evidence/T-0064/engineer/T-0064-AC7_matches_build_runner.md), [cutoff](../evidence/T-0064/engineer/T-0064-AC7_cutoff.md), [not committed](../evidence/T-0064/engineer/T-0064-AC7_generated_not_committed.md), [gen-l10n parity](../evidence/T-0064/engineer/T-0064-AC7_gen_l10n_parity.md); [`T-0042-AC4_safety.sh`](../evidence/T-0064/engineer/T-0042-AC4_safety.md) after `tool/ide_sync` PASS; [50-run flake check](../evidence/T-0064/engineer/runs_per_test_50.md): 750 of 750 over the 15 new and changed targets, then 350 of 350 over the feature after the ADR-0015 changes. `:architecture_test` "the barrel exports only the flow, the navigator and its argument type, each with show", "every file a generator reads imports no Flutter (R15)", "the engine is pure Dart: no Flutter, no timers, no clock, integer arithmetic only, and its imports stay inside it", "the engine check catches a Flutter import, a timer, a leak out of the engine and floating point (negative controls)", "src/ is imported only from test/contract and test/unit (R7; plain unit tests of pure logic are allowed, ADR-0015)", "no lint is suppressed in the package". The `_engine` lane analysed by `--config=lint`. `:contract_test` (every route round-trips through its DTO; the mapper). Analytics: "The round is tracked: started, each answer, finished, and the three screens"; `mini_client:analytics_screens_test` (2 trivia tests) |

### Coverage (AC7)
trivia_quiz 1039/1051 = 98.9 %, chronicle_wiring 40/40 = 100 %, app_core 486/508 = 95.7 %, mc_fixtures_editorial 468/470 = 99.6 % (the 2 unreachable guards of F-0060).

### Mutations
[mutations.sh](../evidence/T-0064/engineer/mutations.sh) (`MC_TASK=T-0064 MC_ROLE=engineer`; it refuses a dirty tree, sets its restore trap before any edit, counts `Build did NOT complete` as BROKEN and only `FAILED in` as a kill; run in a detached worktree on its own output base).
- **At handoff, ADR-0015's 15 targeted mutants: 15 of 15 killed** ([log](../evidence/T-0064/engineer/mutations.log)): scoring (S01 the timeout boundary, S04 the bonus, S08 and E01 the streak), pause and resume (P01 background, P02 covered, P03 the remaining time on resume, P13 the timer at the limit), the hint (S09 its cost, E03 once per round, P05 the flag read once), the results POST (R02 the epoch drop, R03 the pin) and local vs server (R08 the mismatch report, R10 the server's score shown).
- **Before ADR-0015, a full pass: 85 of 85 killed**, none broken or timed out ([log](../evidence/T-0064/engineer/mutations_full_pass.log), at `87ed3be`, the same code as the handoff but for the test changes of ADR-0015). Its first attempt found one survivor, S01: through the flow the countdown's timer always ended the question before the engine could judge an answer at the limit; the harness now lands such a tap just before the timer (F-0064 §5.3), and S01 is killed by the outline's `C20000` row ([partial first pass](../evidence/T-0064/engineer/mutations_pass1_partial.log)). A mutant that is equivalent through the flow (removing the quit dialog's own pause, which the cover pause duplicates) is not in the list; F-0064 trap 6 explains it.

### Hint design
The hint is a contract rule, not a client trick, so the engine and the server still agree (F-0064 §4). An answer may carry `"hint": true`; a correct hinted answer is worth 50 points less (at least 50); a hinted miss is 0; the streak is unchanged by it; at most one per round (`too_many_hints`). The kept wrong choice is a hash of the round and question ids. The `trivia_hint` experiment (`hint` variant) switches it on; it is read once per round. Hiding choices for free (the brief's other option) would make the hint cost nothing, and a client-only penalty would make every hinted round a mismatch.

### Edits outside `feature/trivia/trivia_quiz` and `chronicle_wiring` (TL, please confirm)
- **`utility/mc_fixtures_editorial`** (allowed by the brief for the hint): CONTRACT.md (scoring rule 4, the H1–H5 table, `hint` in the body and breakdown, `too_many_hints`, `comicId` on one-comic questions); `scoring.dart` (`hintPenalty`, `hintsPerRound`, `SubmittedAnswer.hint`, `ScoredAnswer.hint`); the handler (hint validation and limit); `bank.dart` (`comicId` on the wire, needed for `openComic`: the wire named no comic before); the barrel; tests (scoring H rows read from CONTRACT.md, validation, the provider contract's `comicId` check, the oracle's hint, 2 new snapshots and 3 regenerated with `comicId`); `exports_files(["CONTRACT.md"])` for the outline check.
- **`app/wiring/app_core`:** `AppLocations.trivia` and `triviaPlay(...)`.
- **`app/mini_client`:** the Trivia button (last on home) and its callback; `trivia_route_test`; `analytics_screens_test` (2 route names, 2 tests); 2 e2e targets; BUILD; `mc_ds_overlays` as a dev dependency.
- **`tool/l10n_check`** (the trivia ARBs in the gate data), `tool/checks/T-0064-AC7_*.sh`, and the root `pubspec.yaml` (the workspace member; `pubspec.lock` and `MODULE.bazel.lock` are unchanged).

### Test integrity
No test was deleted, skipped or weakened, and there is no `// ignore:`. Existing tests changed: `mini_client:analytics_screens_test` (2 route names added to its set, 2 tests added); `mc_fixtures_editorial`: `provider_contract_test` (the error-code and doc lists gain `too_many_hints`, the served-round test checks `comicId`, a new `comicId` test), `scoring_test` and `validation_test` (new tests only), `support.dart` and `oracle.dart` (an optional `hinted` argument; existing calls unchanged). 3 round snapshots regenerated (they gain `comicId`, nothing else). No golden was added or changed: the 29 feature goldens made before the PO's direction were deleted before handoff (never merged).

### Follow-ups (for `pending-work.md`)
- The iOS back swipe on a linked round's route most likely leaves without the quit dialog (F-0064 trap 5; not tried on a device).
- `app/sandbox/chronicle_sandbox` (P1-23 lists it; out of scope).
- A generic `the experiment {key} is in variant {v}` step in `mc_test_steps` (local here).
