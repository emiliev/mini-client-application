# T-0027: retrofit codegen under Bazel: a SharedPart shim on the rules_dart fork (P3-03, patch 0001)

| Field | Value |
|---|---|
| Status | In Progress |
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

## Log
- 2026-11-24: Created and dispatched (codegen wave, Phase A3).

## Outcome
_Pending._
