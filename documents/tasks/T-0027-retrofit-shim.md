# T-0027: retrofit codegen under Bazel: a SharedPart shim on the rules_dart fork (P3-03, patch 0001)

| Field | Value |
|---|---|
| Status | In Verification (Engineer handoff 2026-11-24) |
| Owner | crew: Engineer (Opus, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0027-retrofit-shim` |
| Created | 2026-11-24 |
| Depends on | T-0024 (patch queue), T-0014 (toolchain), T-0023 (`mc_api_client` / dio) |
| Related | [plan 03 §4 (codegen), KD7, P3-03](../plan/03-bazel-integration.md), [rules_dart research §6](../research/bazel-rules/ai_rules_dart.md), README R10, R12, **R28 (timebox and build_runner fallback)**, F-0007, F-0011, F-0019 |

## Goal
retrofit_generator running as a Bazel action (no build_runner), as a patch on our rules_dart fork that becomes an upstream PR. Feature retrofit APIs (Tide's per-feature `@RestApi`) then build hermetically and cacheably.

## Timebox (R28)
One Engineer pass plus one fix round. If the shim can't be made byte-identical to build_runner within that, stop. Record a precise finding, and the TL switches retrofit to the R28 build_runner fallback.

## Scope
- **In:**
  - Use `tool/rules_fork.sh checkout ai_rules_dart`.
  - Add `dart/ext/retrofit/` (a SharedPart shim plus a macro, following the existing `json_serializable` / `freezed` shims; `builder_shim` is only visible inside the fork).
  - Add `retrofit_generator` (version compatible with retrofit 4.10.0 and the ext lock's analyzer 14.5.0) to the fork's `dart/ext/pubspec.lock`.
  - `export` to `third_party/rules_patches/ai_rules_dart/0001-*.patch`, wired into `MODULE.bazel`, and **`rules_fork.sh check` passes**.
  - A sample `@RestApi` in a spike or test package that uses a freezed+json model and Tide's `ApiResponse<T>` pattern (as in the articles).
  - Upstream PR draft in `documents/upstream/U-D-retrofit/` (repro, versions, patch, Conventional-Commit title, `Changelog:`).
- **Out:** injectable (T-0028), BDD (P3-05).

## Acceptance criteria
- **T-0027-AC1:** Given an `@RestApi` file using a freezed+json model and `ApiResponse<T>`, when built with the shim, then its `.g.dart` equals build_runner's output from the overlay, byte for byte. Use `language_version` (F-0011) and the `sky_engine` dep workaround where needed (F-0007).
- **T-0027-AC2:** Given a body edit in the API file (no signature change), then only that file's retrofit, combine and kernel actions rerun (execution-log evidence).
- **T-0027-AC3:** The ext lock resolves with analyzer 14.5.0; `rules_fork.sh check` and `status` pass; `test //...`, lint and `mc_arch_check` are green with the patch applied.
- **T-0027-AC4:** The upstream draft exists, with a minimal repro workspace.

## Verification map
| AC | Check (name carries the AC ID) | Evidence |
|---|---|---|
| T-0027-AC1 | `tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh` (runs `spike_reference.sh` on `spike/api_envelope` and `spike/retrofit_api`, plus an `aquery` of the retrofit action); the `dart_test` `//spike/retrofit_api:characters_api_test` (cases `T-0027-AC1 …`) exercises the generated client | [T-0027-AC1.md](../evidence/T-0027/engineer/T-0027-AC1.md) |
| T-0027-AC2 | `tool/checks/T-0027-AC2_retrofit_rerun_scope.sh` (body edit, JSON execution log) | [T-0027-AC2.md](../evidence/T-0027/engineer/T-0027-AC2.md) |
| T-0027-AC3 | `tool/checks/T-0027-AC3_patch_queue_and_ext_lock.sh` (`rules_fork.sh check` / `status`, the ext lock as Bazel patched it, `test --lockfile_mode=error //...`, lint, `mc_arch_check`) | [T-0027-AC3.md](../evidence/T-0027/engineer/T-0027-AC3.md) |
| T-0027-AC4 | `tool/checks/T-0027-AC4_upstream_draft.sh` (with `MC_RULES_FORK=<patched checkout>` it also runs the repro) | [T-0027-AC4.md](../evidence/T-0027/engineer/T-0027-AC4.md), [repro run](../evidence/T-0027/engineer/T-0027-AC4-repro.log) |

## Log
- 2026-11-24: Created and dispatched (codegen wave, Phase A3).
- 2026-11-24 (Engineer): The fork commit adds `dart/ext/retrofit/` (shim, `retrofit_library`, BUILD), retrofit_generator 10.3.3 in the ext lock (plus retrofit 4.10.0, dio 5.11.1 and dio_web_adapter 2.2.2; nothing else moves), a direct analysis test, a doc extract and docs. It was exported as `0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch` (347 lines) and wired into `MODULE.bazel`. The fork's own `MODULE.bazel.lock` refresh is left out of the patch: a dependency's lock is never read by consumers, and our refresh was macOS-flavoured (see the upstream draft). New sample packages are `spike/api_envelope` (`ApiResponse<T>` / `ApiPage<T>`, json `genericArgumentFactories`) and `spike/retrofit_api` (a freezed + json `CharacterDto` and an `@RestApi` `CharactersApi`, with per-file staging). `retrofit 4.10.0` joins the root lock; the overlay gains json_serializable 6.14.1, retrofit_generator 10.3.3, retrofit, dio and json_annotation.
- 2026-11-24 (Engineer): The **first pass was byte-identical** for all 5 generated files, so the R28 timebox wasn't needed. One thing had to be fixed on the way (F-0025): a bare `@freezed` model gets no JSON under the shim, so the DTO uses `@Freezed(fromJson: true, toJson: true)`. Rebased onto `origin/main` @ `2bab83d` (T-0026 merged); no conflicts.
- 2026-11-24 (Engineer): Gates on the committed form (pin + patch, no `--override_module`): `test --lockfile_mode=error //...` 48/48, `build --config=lint //...` clean, `mc_arch_check` OK, `rules_fork.sh check` and `status` OK, `tool/test/rules_fork_test.sh` 21/21. `tool/verify.sh` doesn't exist yet (T-0005), so these are the equivalent gates. In the fork workspace, `//dart/ext/... //docs/... //dart/tests:all`: 631 of 633 tests pass. The 2 that fail to build (`dart/tests/defines_fixture`) fail with `DartKernel` exit 247 and have no `dart/ext` dependency. They were not investigated further.
- Test integrity: no tests deleted, skipped or weakened; no lint suppressions.

## Outcome
**Done, pending verification.** retrofit_generator runs as a Bazel action through the fork shim (patch 0001). Its `.g.dart` equals build_runner's byte for byte (`characters_api.g.dart` sha256 `36eebd91a5ab2f756b46e271c0d1dbe5f8f21cda31492298eb180e1f6c55d0ea`), so retrofit stays Bazel-native and the R28 fallback isn't used. A body edit in the API file reruns 11 spawns, all in `//spike/retrofit_api`: retrofit part and combine (×2 configurations, X9), the summary (×2), kernel, analyze, format, link and the test. Nothing in the model or envelope codegen reruns.
- Findings: [F-0025](../findings/F-0025-freezed-json-autodetect-fails-under-bazel-shim.md) (bare `@freezed` loses JSON under the shim), [F-0026](../findings/F-0026-retrofit-shim-spike-facts.md) (spike facts: factory name, ext lock, source_helper pin, rerun scope, the `--disk_cache` measurement gotcha).
- Upstream draft: [U-D-retrofit](../upstream/U-D-retrofit/README.md), with `repro.sh` (verified: test PASS, 3/3 files EQUAL).
- Follow-ups for the TL (pending-work candidates): (1) templates and buildgen must emit `@Freezed(fromJson: true, toJson: true)` and flag bare `@freezed` + `fromJson` (F-0025), a recorded Tide deviation; (2) `mc_codegen` (P3-06) wiring for `retrofit = [...]` with per-file staging (F-0026 §Implications); (3) upstream issue candidates: the shim's source `fullName` vs build_runner's asset paths (F-0025), and Gazelle `@RestApi` registration plus an `e2e/ext_exemplar/retrofit` exemplar (U-D-retrofit follow-ups); (4) `mc_api_client` doesn't have `ApiResponse<T>` / `ApiPage<T>` yet, and the spike envelope is the template for it (P1-05 follow-up).
