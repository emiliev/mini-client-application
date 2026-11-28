# T-0078: `mcgen` interactive (IX) archetype: `trivia_quiz` regenerates byte for byte

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet), reusing the T-0073 engineer |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0078-mcgen-interactive` |
| Created | 2026-11-28 |
| Depends on | T-0065, T-0069 (ADR-0017), T-0074 (ADR-0018), T-0064 (the IX exemplar, ADR-0014: pure-Dart engine in `domain/engine/`, injected monotonic clock) |
| Related | plan 02 P2-05–P2-07; F-0064; F-0069, F-0072–F-0076 |

## Goal
Add the IX archetype. `trivia_quiz` must round-trip. It is the only IX module, so **the probes carry the generalisation proof**, and they must use a different engine and different rules.

## Scope
- **In:**
  - `emit/feature_interactive/` and `bricks/feature_interactive_*`.
  - The spec (`exemplar: true`) and keep markers.
- **Template coverage:**
  - setup, play and results pages;
  - the engine boundary: a pure-Dart `domain/engine/`, kept owned or behind keep regions, with the clock and ticker injected;
  - pause on lifecycle or cover;
  - outer-route guard;
  - painters, which stay owned;
  - the results POST pinned with the session epoch;
  - a Scenario Outline driven by rule examples (R6).
- **Lint:** covers every role. Escape with `dartString`.
- **No BUILD or `flow_scope`.** The pubspec carries the root-import packages.
- **Probes:** gen → wire → buildgen. `wire` doesn't route IX yet, so it must warn only.
- **Parallel work:** T-0077 (ST archetype) and T-0079 (wire routing) are running. Own your own `emit/` and `bricks/` subtrees, plus one line in `archetypes.dart`.
- **Out:** behaviour changes.

## Acceptance criteria
- **T-0078-AC1:** `gen trivia_quiz --check` exits 0. A one-field change exits 1 and names the file.
- **T-0078-AC2:** `trivia_quiz` is unchanged. Its Bazel tests and the app tests pass, and its diff is markers, spec and manifest only.
- **T-0078-AC3:**
  - Two throwaway IX probes generate, analyse clean and pass BDD (including a Scenario Outline) under Bazel:
    - a timed probe;
    - an untimed one with a different engine.
  - Lint-rejection tests cover every role.
- **T-0078-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, the format gate, `T-0065-AC5_gates.sh`.
  - Every existing `--check` and `check --all` is clean.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A short finding with the hand share.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the fourth wave.
