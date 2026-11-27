# ADR-0014: An interactive feature's engine is pure Dart in the feature, and time enters it through the flow

- **Status:** Proposed (T-0064 engineer; for the TL to accept at the merge)
- **Date:** 2026-11-27
- **Deciders:** Tech Lead
- **Related:** T-0064, P1-23, plan 01 §3.3 and §6.1 (IX), R6, R15, R17, ADR-0007, ADR-0010, ADR-0012, F-0064, F-0060

## Context
`trivia_quiz` (T-0064) is the first IX feature, and the P1-24 bricks copy it for about ten interactive features (`trivia_daily`, `timelines_explorer`, ...). Each has rules of its own (scoring, a game state) and a clock (a countdown, a timeline that plays). Two choices are costly to change once the bricks have copied them:

1. **Where the rules live and how they are tested.** R6 says features have no `test/unit/`, and "feature-specific engines run as Scenario Outlines through the flow". The engine must also agree with the server to the point (the server rescores every round, `mc_fixtures_editorial` CONTRACT.md).
2. **How time reaches the rules.** A countdown needs a clock and timers. The tests must be exact to the millisecond (`limit - 1` still counts, `limit` is a timeout) and must not flake (DoD 50-run check). R15 forbids Flutter in anything a generator reads, which includes the blocs.

`flutter_test`'s `testWidgets` runs on fake time: `Timer`s are fake, and `TestWidgetsFlutterBinding.instance.clock` is the fake clock. `Stopwatch` and `DateTime.now()` are real. `package:clock` would follow the fake zone, but it is not a direct dependency of any package, and adding one changes `pubspec.lock` (a shared file) for one feature.

## Options considered
### Engine
#### A. A pure-Dart engine in the feature's domain, tested only through the flow (chosen)
- Pros:
  - R6 as written: the outline of the contract's worked examples runs through the real flow, the real backend and the real server scoring, so "local equals server" is checked on every row.
  - No new package per feature: an engine is feature-specific by definition.
  - An `_engine` `dart_library` (only pure-Dart deps) and the architecture test's import-closure check (with negative controls) keep it free of Flutter, timers and floating point.
- Cons:
  - A rule mutant is killed only by a BDD scenario, so the feature's BDD target is the engine's test target (about 10 s per run).

#### B. The engine in a utility package with solitary unit tests
- Pros: fast tests, the usual utility shape.
- Cons: one package per IX feature (about ten), a shared home for rules that belong to one feature, and R6 says the opposite.

#### C. The rules in the bloc
- Pros: fewer files.
- Cons: the bloc then mixes time, I/O and rules; a scoring mutant is hard to tell from a timing one, and the bricks copy a tangle.

### Time
#### a. The flow takes a monotonic clock (`int Function()`), and the feature runs `dart:async` timers on it (chosen)
- Pros:
  - The same shape as the store's `clock` (T-0056): the app passes a `Stopwatch` reading (`chronicleClock`), the tests pass the binding's fake clock (`triviaClock`). Timers are real `Timer`s in both, fake under `testWidgets`, so `tester.pump(d)` moves the clock and the timers together and an answer's elapsed time is exactly the time pumped.
  - No dependency, no lockfile change; the flow provides it (`provide:`), so it is not a root import.
  - Monotonic: a change of the device's wall clock cannot add time to a question.
- Cons:
  - A test that forgets to use the fake clock (passes `DateTime.now`) gets real time against fake timers. The env helper is the only clock tests use.

#### b. `package:clock` (`clock.stopwatch()`) inside the feature
- Pros: nothing to pass; fake in tests automatically.
- Cons: a new direct dependency and a `pubspec.lock` change for every IX brick; a hidden global.

#### c. A ticker interface the app implements and tests double
- Pros: full control.
- Cons: the timers would be test code, not the feature's; the double's behaviour is what the tests would prove.

## Decision
1. **An IX feature's rules are a pure-Dart engine in `lib/src/domain/engine/`** (`scoring.dart` for the arithmetic, `<feature>_engine.dart` for the state machine). It takes time as numbers (`elapsedMs`), never a clock or a timer, and it imports only its own model files and annotations. Integer arithmetic only where a server must agree.
2. **The engine is tested through the flow** (R6): a Scenario Outline whose Examples are the backend contract's worked examples verbatim, a test that checks the two tables are the same rows, and per-row checks that the score shown before and after the save is the row's and that no mismatch was reported.
3. **Time enters through the flow:** `TriviaQuizFlow(clock: int Function() /* monotonic ms */, nextSeed: int Function())`, provided into the flow's container as `TriviaTicker(clock)` and `RoundSeeds(nextSeed)`. The play bloc owns a `QuestionClock` over it (start, pause, resume) and two `Timer`s: a frame tick (100 ms) to redraw, and a one-shot at the question's remaining time that ends it exactly at the limit.
4. **The countdown runs only while someone can play:** in `AppLifecycleState.resumed`, with the flow's route current (`FlowScope.outerIsCurrent`) and no quit dialog. Each is a pause reason; the clock resumes when none is left.
5. **Enforcement:** the `_engine` lane in `BUILD.bazel` (analysed under `--config=lint` with pure-Dart deps only) and `:architecture_test` (the engine's import closure, floating point, negative controls).

## Consequences
- **Positive:**
  - Bricks get one shape for rules (engine + outline) and one for time (flow-provided clock + feature timers).
  - The 17 contract rows and the 5 hint rows prove local equals server on every run, and every rule mutant (bonus, streak, timeout boundary, hint) is killed by them (T-0064 mutations).
  - Timer tests are exact and deterministic: 50 of 50 runs.
- **Negative / trade-offs:**
  - The engine has no fast test of its own; its mutants cost a BDD run each.
  - Two time sources exist in a feature test: fake time (timers, the injected clock) and real time (`Stopwatch`, used nowhere in the feature). A brick must not read `DateTime.now()` in a bloc.
  - The countdown keeps scheduling frames while a question is open, so a step that settles (`mcSettle`, `pumpAndSettle`) waits for the question to time out: play steps pump explicit durations instead (F-0064 §5).
- **Follow-ups:**
  - P1-24: the IX brick's `engine/`, its outline template fed from the contract table, and the env's `triviaClock` helper.
  - `mcgen wire` lists the clock and seed types as flow-provided (not root imports).
