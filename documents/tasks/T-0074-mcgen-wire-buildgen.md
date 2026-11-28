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
- 2026-11-28 (Engineer, Opus):
  - Probed the 11 feature BUILD files against the import graph. `_PURE_DEPS` derive exactly. `_FLUTTER_DEPS` match in 8 of 11. `_TEST_DEPS` are always a superset of the imports of the step and util files.
  - The extras are over-approximations, so a pure template would change all 11 graphs. So buildgen merges instead (ADR-0018): it keeps prose, `# keep` items and one hand region.
  - Captured `bazel query` before, ran `buildgen --adopt` over the 11 files, captured after: identical in all four views (labels, kinds, 29,921 edges, every target's attributes). Then moved the app's wiring list to `wirings.bzl`: identical again.
- 2026-11-28 (Engineer):
  - Wire derives all 11 `flow_scope.dart` files byte for byte, once `context.di<T>()` reads count.
  - Added the app's wiring list (`wirings.dart`), `wirings.bzl`, `GeneratedLocations`, the `/catalogue` debug route and its test, and generated wiring groups.
  - Moved the list-detail BUILD template and `flow_scope.dart` out of the archetype (P-126). `characters_list` still round-trips.
  - The first AC3 probe run failed: `app_test` asserted `hasLength(7)` wirings, and the probe's own `grep -q` failed under pipefail. Fixed both.
- 2026-11-28 (Engineer):
  - Merged `origin/main` (T-0073).
  - The search archetype still rendered `flow_scope.dart`. It now leaves the file to wire, keeps the list's packages in its pubspec, and its two exemplar manifests were regenerated.
  - The probe passes on the merged HEAD: sim build, `test //...` 252 of 252, the new flow opens from `/catalogue`. The gates are green.
- 2026-11-28 (Engineer):
  - Merged `origin/main` again (T-0072).
  - The section-detail archetype rendered both moved files. It now leaves them to buildgen and wire, keeps the list's packages in its pubspec, and its two exemplar manifests were regenerated.
  - The LD, SC and SR probe scripts run `wire` (and LD/SC `buildgen`) for their module: all three PASS under Bazel.
  - Re-ran the gates and the AC3 probe on `ee8474a8`. All are green: `test //...` 247 of 247; lint; `mc_arch_check`; the sim build; a 20-run flake check of `catalogue_test`, `analytics_screens_test` and `app_test`; the format gate; rules_fork; unchanged lockfiles; 211 mcgen tests; CI gate 6. The AC3 probe passed with a sim build and 252 of 252.

## Outcome
- **Changed** (branch `fleet/T-0074-mcgen-wire-buildgen`; handoff HEAD in the report):
  - `tool/mcgen/lib/src/{buildgen,wire}/`, the CLI, `mcgen.yaml` `wire:`, and the README;
  - the list-detail archetype (no BUILD template, no flow scope: P-126), the search archetype (no flow scope) and the section-detail archetype (no BUILD output, no flow scope), and their probe scripts;
  - the 11 feature BUILD files (adopted, graph-neutral), the root pubspec (members sorted), the exemplar specs and manifests;
  - `app/mini_client`: `wirings.dart`, `wirings.bzl`, the router, `catalogue_test`, and `app_test` / `analytics_screens_test` adjusted;
  - `app_core`: `CataloguePage`, `GeneratedLocations`, `AppLocations.catalogue`;
  - `tool/ci/ci.sh` gate 6 also runs `wire --check` and `buildgen --check`.

| AC | Evidence |
|---|---|
| T-0074-AC1 | `tool/mcgen/test/buildgen_test.dart`: 11 `T-0074-AC1 …` tests, including `buildgen --check exits 0 on the repo: every feature BUILD file is up to date` and `adopt marks unexplained items # keep and moves unknown statements into the hand region, so the file builds the same`. Graph neutrality: [T-0074-AC1_graph_neutral.md](../evidence/T-0074/T-0074-AC1_graph_neutral.md) |
| T-0074-AC2 | `tool/mcgen/test/wire_test.dart`: 6 `T-0074-AC2 …` tests, including `wire --check exits 0 on the repo, every covered file up to date` and `root imports: injectable constructors, modules and scope reads, …`. Covered and uncovered files: F-0074 §4 |
| T-0074-AC3 | [T-0074-AC3_wire_probe.md](../evidence/T-0074/T-0074-AC3_wire_probe.md): temp copy, the spec added by hand and nothing else, gen, wire and buildgen, sim build, `test //...` 252 of 252. `app/mini_client/test/catalogue_test.dart`: 3 `T-0074-AC3 …` tests (`the catalogue opens zz_ld_probe at its route, …` ran in the probe). `wire_test.dart`: 2 `T-0074-AC3 …` tests |
| T-0074-AC4 | [T-0065-AC5_gates.md](../evidence/T-0074/T-0065-AC5_gates.md) (mcgen tests; lockfiles unchanged), `T-0074-AC4_{test,lint,arch,sim,flake20,format,rules_fork,lockfiles,ci_gate6}.log`, [T-0074-AC4_archetype_probes.md](../evidence/T-0074/T-0074-AC4_archetype_probes.md) (the LD, SC and SR probes still pass). F-0074 written; ADR-0018 drafted |

- **Test integrity:**
  - `list_detail_test` now compares 54 files, not 56, and expects no BUILD or flow scope: those moved to buildgen and wire, and their own tests cover them. `section_detail_test` likewise: 48 and 49, not 50 and 51.
  - `section_detail_review_test` checks the two-word item's freezed targets in the BUILD file that buildgen writes for the rendered module. A new module's targets are named after their files (`story_arc_details_bloc`), not the old template's `details_bloc`.
  - `cli_test` no longer lists wire and buildgen as "not yet".
  - `app_test`'s "all 7 wirings are composed" names the 7 initializers in order instead of `hasLength(7)`, so a generated group may follow them.
  - `analytics_screens_test` expects `catalogue` plus one route per catalogue entry.
  - Nothing was skipped. No `// ignore` was added.
- **Decisions:** ADR-0018 (Proposed).
- **Findings:** F-0074.
- **Follow-ups** (F-0074, Implications): route specs so wire can own the hand-written groups; shrink the 75 `# keep` items; drop the search skeleton's owned BUILD (and SC's, T-0072); buildgen for utility packages.
