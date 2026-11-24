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
- 2026-11-24: Engineer (resumed after the usage-limit stop; worktree re-created on the existing branch, fast-forwarded to `e630d67`). Fork patch **`0002-ext-injectable-two-stage.patch`** (`dart/ext/injectable/`: `shim_json`, `shim_config`, `defs.bzl` with `injectable_package`, Builder wrappers + unit test, vendored injectable_generator 3.1.3 without `lib/lean_builder/` with `VENDORED.md` provenance, `injectable 3.0.0` in the ext lock, `docs/ext.md`). Sample `spike/di_sample` (5 annotated classes + a comment-only file + `@InjectableInit` via `McDIInitializer`). First pass: byte-identical on the plain sample, but **not** once the barrel is staged or a class takes `Dio` (the shim's `Resolver.libraries` order, F-0028). Fix round: both shims use a build_runner-order resolver; byte-identical in all cases. R28 fallback not needed. Gates green (see Outcome).
- 2026-11-24: Verifier PASS (`ced0c05`). Code-review fix round (Engineer): (1) `injectable_reference.sh` exits 1 when the Bazel build or build_runner fails, and compares only the outputs the targets declare (`cquery --output=files`; a stale shard in bazel-bin is ignored, checked); (2) AC3 check queries the hub by its canonical name `@@ai_rules_dart++pub+ext_pub_deps` with a positive control (analyzer, injectable listed), fails if the fetch or the query fails, and fails when the archive comparison can't run (offline = NOT CHECKED); (3) AC2 check requires the edited file's shard spawn with `cacheHit=False` and fails on any `DartAggregateCodegen` spawn without `cacheHit=True`; (4) finding renumbered F-0026 → **F-0028** everywhere (fork comment included; the Verifier's report keeps its original wording); (5) the sample test that claimed AC4 is renamed (the shell check is the AC4 evidence); (6) `injectable_shards` fails naming both files when two sources map to the same target suffix (checked with `a_b.dart` vs `a/b.dart`); (7) `LICENSE` is byte-identical in the fork; Bazel's patcher appends a final newline (it ignores `\ No newline at end of file`), now documented in `VENDORED.md`; (8) `_stage` comment explains why the barrel's dangling export of the init file is harmless, proved by AC1 with the barrel staged. Patch 0002 re-exported, `check` passes. Gates and all four AC checks re-run: PASS.
- 2026-11-25: Re-verify PASS (`871f90a`). Brought onto `origin/main` `cf3218b` (T-0027 merged) with a merge, not a rebase: seven branch commits touch `pubspec.lock` / `MODULE.bazel.lock`, which a rebase would conflict on one by one. Root: `pubspec.yaml` workspace list is the union (`spike/api_envelope`, `spike/di_sample`, `spike/retrofit_api`); `fvm flutter pub get` re-resolve equals the textual union; `MODULE.bazel.lock` regenerated by Bazel; `MODULE.bazel` patches = 0001, 0002. **Patch 0002 rebased onto 0001** in a fresh fork (`checkout` applies 0001; 0002 re-applied with `git am -3`): `dart/ext/pubspec.yaml` puts `injectable: ^3.0.0` in sorted position among the generators (after `go_router_builder`, before `json_serializable`; 0001 added `retrofit_generator`); `dart/ext/pubspec.lock` **re-resolved** with `fvm dart pub get` (Dart 3.13.5) = 0001's lock plus `injectable 3.0.0` only, **no version moved** (analyzer 14.5.0, build 4.0.11, source_gen 4.3.1, dart_style 3.1.14, code_builder 4.13.0, dio and retrofit_generator as 0001 left them); `docs/ext.md` tree lists `retrofit/` (0001) and `injectable/`; no fork `MODULE.bazel.lock` in either patch. `export` renumbered 0001's subject to `[PATCH 1/2]`, so 0001 was restored byte-identical from `main` (0002's header reads `[PATCH 2/2]`; `check` passes either way). Gates: `rules_fork.sh check` 2 patches strict; `test --lockfile_mode=error --nocache_test_results` on the T-0027 and T-0028 targets 3/3; `test --lockfile_mode=error //...` 49/49; `build --config=lint //...` clean; `mc_arch_check` OK; T-0028 AC1 to AC4 PASS; T-0027 AC1 PASS (5 of 5 EQUAL, retrofit output unchanged after the joint resolve) and AC2 PASS ([t0027-ac1-after-rebase.md](../evidence/T-0028/engineer/t0027-ac1-after-rebase.md), [t0027-ac2-after-rebase.md](../evidence/T-0028/engineer/t0027-ac2-after-rebase.md)).

## Outcome
**Done** (Engineer, awaiting a fresh Verifier). One pass plus one fix round, within R28.

| AC | Evidence | Result |
|---|---|---|
| T-0028-AC1 | `tool/checks/T-0028-AC1_injectable_matches_build_runner.sh` → [ac1.md](../evidence/T-0028/engineer/ac1.md); `//spike/di_sample:di_sample_test` (`T-0028-AC1 …`) | PASS: `.config.dart` and 5 shards `EQUAL` (build_runner 2.16.1 + stock injectable_generator 3.1.3 with lean_builder, `tool/build_runner_overlay/injectable/`) |
| T-0028-AC2 | `tool/checks/T-0028-AC2_di_cutoff.sh` → [ac2.md](../evidence/T-0028/engineer/ac2.md), [ac2-execlog.json](../evidence/T-0028/engineer/ac2-execlog.json) | PASS: body edit → 6 `DartCodegen` spawns, **no `DartAggregateCodegen` spawn**, shard + config sha256 unchanged; aggregate's package inputs = init file + 6 shards |
| T-0028-AC3 | `tool/checks/T-0028-AC3_ext_lock.sh` → [ac3.md](../evidence/T-0028/engineer/ac3.md) | PASS: analyzer 14.5.0, injectable 3.0.0, no lean_builder; vendored `lib/` = pub.dev archive minus `lib/lean_builder/` |
| T-0028-AC4 | `tool/checks/T-0028-AC4_empty_shard_and_failing_init.sh` → [ac4.md](../evidence/T-0028/engineer/ac4.md); `@rules_dart//dart/ext/injectable:injectable_shims_test` (`T-0028-AC4 …`) | PASS: `plain_helper` shard `[]`, config builds; no-`@InjectableInit` and unresolved-annotation targets fail, nothing written |
| T-0028-AC5 | this log | PASS: `rules_fork.sh check ai_rules_dart` (1 patch applies strictly); `test //...` 48/48; `build --config=lint //...` clean; `mc_arch_check` OK; drafts `documents/upstream/U-D-injectable/`, `documents/upstream/U-X-injectable-lean_builder/` |

Notes for the TL:
- **Patch numbering:** exported as `0001`, renamed to `0002-ext-injectable-two-stage.patch` (content untouched). Checked that it applies with `git am` on top of T-0027's current fork WIP commit (`wip: retrofit shim`). Both patches touch `dart/ext/pubspec.yaml`, `dart/ext/pubspec.lock` and `docs/ext.md` in different hunks; after combining, regenerate the ext lock with both (`fvm dart pub get` in a copy of `dart/ext`) to confirm it is the union, then `rules_fork.sh check`.
- **Root lock:** adds `injectable 3.0.0` (T-0027 may also touch `pubspec.lock` / `MODULE.bazel.lock`; regenerate on merge).
- **Overlay split:** the injectable reference has its own pubspec/lock (`tool/build_runner_overlay/injectable/`) because lean_builder forces analyzer 14.1.0 (F-0028 §3).
- No tests were deleted, skipped or weakened; no `// ignore:` added. `tool/verify.sh` does not exist yet; the equivalent gates above were run.

Follow-ups (for `pending-work.md`):
- An `e2e/ext_exemplar/injectable/` exemplar and Gazelle support in the upstream PR.
- The general `Resolver.libraries` fix in `builder_shim.dart` (U-D-injectable follow-up issue).
- Narrower shard deps in buildgen, so an edit re-runs one shard, not all (F-0028 §5).
- Micro-package `.module.dart` output: untested.
- `InjectableConfigBuilder`'s shard check uses a hard-coded `lib/**.injectable.json` glob, not the annotation's `generateForDir`.
- An annotated file missing from `srcs` is silently dropped from the config (no shard); buildgen's annotation scan must cover it.
- `tool/build_runner_overlay/injectable_reference.sh` is hard-coded to the sample's first-party deps (`mc_di`); generalise it (as `spike_reference.sh` does) before using it on other packages.
- Rebase patch 0002 onto T-0027's 0001 once T-0027 is merged (TL request), regenerate the ext lock with both, re-export, `check`.
