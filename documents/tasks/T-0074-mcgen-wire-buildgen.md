# T-0074: `mcgen wire` and `mcgen buildgen`: generated app glue and BUILD files (P2-08)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: novel; batches depend on it) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0074-mcgen-wire-buildgen` |
| Created | 2026-11-28 |
| Depends on | T-0065 (core), T-0069 (list-detail archetype; its BUILD template and `flow_scope.dart` are to move here, P-126) |
| Related | plan 02 §2.8 (wire-owned files), P2-08 (AC1: "Given the S0 specs, when wire and buildgen run, then the app builds with `--config=sim` and every flow is reachable from the catalogue screen"); plan 01 §3.4 and §4.2 (wirings, `RouteTargets`, `AppLocations`, `nestUnderHome`); F-0049, F-0066 (guard) |

## Goal
Batches (Phase E) must not hand-edit app glue. `mcgen wire` regenerates the shared wiring from every spec. `mcgen buildgen` regenerates `BUILD.bazel` files from pubspecs and the import graph. A merge conflict in those files is then resolved by regenerating, never by hand.

## Scope
- **In:**
  - **`buildgen` (`tool/mcgen/lib/src/buildgen/`).**
    - Writes a package's `BUILD.bazel` from its pubspec, its resolved imports and its test files, using the repo's macros (`MC_GENERATED_DART` and friends).
    - **Start in `--check` mode against the existing hand-written BUILD files.** The goal is that `buildgen --check` agrees byte for byte with every feature package's BUILD.
    - Where the hand-written files vary, define the canonical form, regenerate the files into it, and prove the Bazel graph is unchanged. Compare `bazel query 'deps(//...)'` output before and after.
    - Move the list-detail BUILD template here (P-126).
  - **`wire` (`tool/mcgen/lib/src/wire/`).**
    - From the specs, generate the wire-owned files listed in plan 02 §2.8:
      - each wiring's route library and `RouteTargets`;
      - navigator-implementation skeletons (written once, then `owned`);
      - `AppLocations` entries and their drift tests;
      - each feature's `flow_scope.dart`;
      - the app's wiring list and pubspec deps;
      - the root workspace members.
    - **Start in `--check` mode against the current hand-written wiring.** Aim for as many of those files as possible to regenerate byte for byte, and document each one that can't.
    - Respect the sign-in guard's protected prefixes (F-0066) and `nestUnderHome` (F-0049).
  - **Catalogue screen (P2-08 AC1).** It lists every generated flow so each one is reachable, which is what the batches need. A minimal `/catalogue` debug route in the app, hidden from home or behind a dev flag, is enough.
- **Parallel work:** T-0072 (SC archetype) and T-0073 (SR archetype) are running. Own `tool/mcgen/lib/src/{wire,buildgen}/`. Changes to hand-written BUILD or wiring files are allowed only where `--check` agreement requires them, and each must be proven graph-neutral.
- **Out:** spec synthesis, batch generation.

## Acceptance criteria
- **T-0074-AC1:** `mcgen buildgen --check` agrees with every `feature/**` BUILD file, and with the utility BUILD files the archetypes cover. Any normalisation is graph-neutral, shown by a diff of `bazel query 'deps(//...)'` before and after.
- **T-0074-AC2:** `mcgen wire --check` agrees with the wire-owned files it covers. Each uncovered file is listed with the reason.
- **T-0074-AC3 (P2-08 AC1):**
  - Probe: in a temp copy, add one new list-detail spec, then run `gen`, `wire` and `buildgen`.
  - The app builds with `--config=sim`, `test //...` is green, and the new flow is reachable from the catalogue route (a widget test).
  - Nothing in that copy was edited by hand.
- **T-0074-AC4:**
  - Gates: `test --lockfile_mode=error //...`, lint, `mc_arch_check`, the format gate, `T-0065-AC5_gates.sh`, and `tool/ci/ci.sh --only` for the mcgen gate.
  - The lockfiles are unchanged.
  - Every cited test exists.
  - A finding is written, plus an ADR draft if the wire-owned file layout or the BUILD canonical form is costly to reverse.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the third wave.
