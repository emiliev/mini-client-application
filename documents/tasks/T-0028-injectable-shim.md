# T-0028: injectable codegen under Bazel: two-stage shim, vendored generator (P3-04, patch 0002)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Opus, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0028-injectable-shim` |
| Created | 2026-11-24 |
| Depends on | T-0024, T-0014, T-0017 (`mc_di`) |
| Related | [plan 03 §4.2, KD7, X3, P3-04](../plan/03-bazel-integration.md), README R12 and **R28 (timebox and fallback)**, V3-04 (aggregate deps), F-0007, F-0011 |

## Goal
injectable_generator (an aggregate builder: per-file `.injectable.json`, then one `.config.dart`) running under Bazel. It's vendored as 3.1.3 **without `lean_builder`**, whose `_fe_analyzer_shared <106` clashes with the ext lock's analyzer 14.5.0. Tide generates every package's DI initializer with injectable.

## Timebox (R28)
One Engineer pass plus one fix round. Otherwise stop with a precise finding, and the TL switches injectable to the build_runner fallback.

## Scope
- **In:**
  - On the rules_dart fork: `dart/ext/injectable/` with stage 1 (a per-file `dart_codegen` writing `.injectable.json`) and stage 2 (a `dart_aggregate_codegen` writing `.config.dart`), plus the vendored `injectable_generator` 3.1.3 minus `lib/lean_builder/` (licence kept).
  - Stage 2's deps are only the stage-1 JSON shards plus the injectable and get_it annotations (V3-04), so a body edit that doesn't change DI is a cache hit for the aggregate.
  - Exported as the next patch in the queue (`check` passes).
  - A sample package with 5 annotated classes plus an `@InjectableInit` file, wired through `mc_di`'s `McDIInitializer`.
  - Upstream drafts: rules_dart (the shim), and injectable / lean_builder (the analyzer-range issue).
- **Out:** retrofit, BDD.

## Acceptance criteria
- **T-0028-AC1:** Given 5 annotated files and an `@InjectableInit` file, when built, then `.config.dart` equals build_runner's output, byte for byte.
- **T-0028-AC2:** Given a body edit that doesn't change DI, then the aggregate action is a **cache hit** (H-DI-CUTOFF; execution-log evidence).
- **T-0028-AC3:** The ext lock resolves with analyzer 14.5.0 and contains no `lean_builder`.
- **T-0028-AC4:** Given an annotated file that yields no dependencies, then its shard is `[]` and the config stage succeeds. Given an `@InjectableInit` whose generation yields nothing, then the build fails instead of writing an empty `.config.dart`.
- **T-0028-AC5:** `rules_fork.sh check` passes; `test //...`, lint and `mc_arch_check` are green; the upstream drafts exist.

## Log
- 2026-11-24: Created and dispatched (codegen wave, Phase A3).

## Outcome
_Pending._
