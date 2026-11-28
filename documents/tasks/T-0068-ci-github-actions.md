# T-0068: CI: a GitHub Actions workflow that builds and tests with Bazel on every delivery (URGENT)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-28 `fe063d24`; green cold and warm on GitHub, red on failure) |
| Owner | crew: Engineer (Sonnet, worktree). The TL pushes the branch and relays CI logs, because crew never push. |
| Verification | ADR-0015: `/code-review`, then the TL merge gates, **plus a green CI run on GitHub** |
| Branch | `fleet/T-0068-ci` |
| Created | 2026-11-27 |
| Depends on | T-0062 (the format gate, `tool/README`), T-0055 (`tool/e2e_ios.sh`) |
| Related | superseded T-0005; plan 03 §2 (`build:ci`, lockfile `error`, clean-clone run), R10, R11; ADR-0004, ADR-0015; F-0002 (remote; the token has the `repo` and `workflow` scopes, and Actions is enabled) |

## PO decisions (2026-11-27)
- **Runner:** GitHub-hosted **macOS** on Apple Silicon (`macos-15` or newer). The Bazel Flutter toolchain and the DS goldens are macOS-based. Bazel's disk and repository caches persist in `actions/cache`, because private-repo macOS minutes bill at 10×.
- **Triggers:**
  - push to `main` (every delivered feature);
  - push to `fleet/**` (the TL may push a task branch before merging);
  - `pull_request`;
  - `workflow_dispatch`.

## Goal
Every delivery runs the same gates as the TL's merge gate, on a clean machine. A red `main` is visible within the hour.

## Scope
- **In:**
  - **`tool/ci/ci.sh`.** One entry point that runs the gates in order and stops on the first failure, with a clear step banner. CI and humans run the same script.
    1. `tool/rules_fork.sh check`
    2. `bazel test --config=ci //...` (lockfile `error`, `--keep_going`)
    3. `bazel build --config=ci --config=lint //...`
    4. `bazel run //tool/mc_arch_check:bin`
    5. the format gate (`tool/checks/lib/format_gate.sh`)
    6. `tool/l10n_check`
    7. `tool/checks/T-0035-AC4_provenance.sh`
    8. the no-direct-overlay check
    9. `bazel build --config=ci --config=sim //app/mini_client:mini_client_ios`
    10. the `app`-tagged tests in their own invocation, if any exist (`--config=app`, plan 03)

    If a gate has a hidden dependency on this Mac, make it portable or put it behind a clear switch, and document it. Known examples:
    - `tool/bazelw` hard-codes `/opt/homebrew/opt/bazelisk`; `MC_BAZELISK` exists for this.
    - The format gate uses `fvm dart`. Use the Bazel-provided Dart SDK or a pinned Flutter 3.47.7 setup step.
  - **`.github/workflows/ci.yml`.**
    - The triggers listed above.
    - `concurrency` per ref, so a newer push cancels an older run of the same branch.
    - `timeout-minutes` of about 120 for a cold run.
    - Third-party actions pinned to a commit SHA. Use `bazel-contrib/setup-bazel` or plain bazelisk plus `actions/cache`.
    - Cache keys on `MODULE.bazel.lock`, `.bazelversion` and the workflow file, with restore keys. Mind the 10 GB per-repo cache cap: measure the disk-cache size and trim or split it if needed.
    - On failure, upload `bazel-testlogs/**/test.log` for failing targets and the ci.sh log as an artifact.
    - No secrets are needed or used.
  - **Docs.**
    - A CI section in `tool/README.md`: what runs, how to reproduce locally (`tool/ci/ci.sh`), and expected cold and warm durations.
    - A status badge in `README.md`.
    - A finding, `F-0068-ci-github-actions.md`. Cover cold vs warm time, cache size, anything that differed on a clean runner, and the minutes cost per run.
- **Out:** e2e on the simulator in CI (later, if the PO wants it), Android, branch protection (the PO may turn it on later), remote cache.

## Acceptance criteria
- **T-0068-AC1 (local proof):** `tool/ci/ci.sh` passes on a **fresh clone** of your branch on this Mac, with no `.dart_tool` and no IDE-synced files. Record the time per gate.
- **T-0068-AC2 (workflow lint):** `ci.yml` is valid. Run `actionlint` if available (installing it via Homebrew is fine), otherwise a YAML and schema check. Every third-party action is pinned to a SHA.
- **T-0068-AC3 (green on GitHub):** the TL pushes `fleet/T-0068-ci`. The run passes on a cold cache, and a second run passes on a warm cache. Record both durations.
- **T-0068-AC4 (it fails when it should):** on a throwaway branch the TL pushes, a deliberately failing test makes the run red and uploads that test's log. The TL deletes the branch afterwards.
- **T-0068-AC5:** the docs, badge and finding exist. `test --lockfile_mode=error //...` is still green locally, and the lockfiles are unchanged.

## Log
- 2026-11-27: Created and dispatched (TL). The PO asked for it urgently and chose macOS with caching, triggered on `main` + `fleet/**` + PRs + manual runs. It runs as a 4th concurrent agent (above the usual 3) because it is urgent and small. Checked first: the keychain token has the `workflow` scope, and Actions is enabled with all actions allowed.
- 2026-11-27 (Engineer): Wrote `tool/ci/ci.sh` (10 gates, per-gate time table), `.github/workflows/ci.yml`, made `tool/bazelw` (bazelisk on PATH fallback) and `format_gate.sh` (`MC_DART`) portable, added the `tool/README.md` section, README badge, `ci-logs/` ignore and F-0068.
  - AC1: fresh clone of the branch in `/tmp`, own output base, empty `--disk_cache` and `--repository_cache`: all 10 gates PASS in 341 s (test 251, sim build 67, the rest 1 to 5 s each). Warm disk cache with a new output base: 49 s. 223 tests pass.
  - AC2: `actionlint` clean; actions pinned to SHAs (checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2).
  - AC5: lockfiles unchanged (clean `git status` after the run); `--config=ci` has `--lockfile_mode=error`.
  - AC3 and AC4 need the TL's push; pending.

## Outcome
Implemented and proven locally (AC1, AC2, AC5). Cache sizes: repository 3.5 GB, disk 1.3 GB, bazelisk 0.2 GB. AC3 (cold and warm GitHub runs) and AC4 (failing-test branch) are waiting for the TL push; the GitHub durations go in F-0068 after that. Details: [F-0068](../findings/F-0068-ci-github-actions.md).
- 2026-11-27 (Engineer): CI run 1 failed at the format gate (`sky_engine` missing in a fresh Flutter clone). Fixed: `MC_PUB_GET=flutter pub get` in the workflow and gate, plus `flutter precache --universal` after the clone or cache restore. Verified with a fresh local clone; see F-0068.
- 2026-11-27 (Engineer): Merged origin/main (T-0065) and added gate 6, `tool/mcgen` (`pub get` in `tool/loc` and `tool/mcgen`, `dart analyze --fatal-infos`, `dart test`, 96 tests): PASS locally with `fvm` (27 s) and in CI mode (`MC_DART=dart`, online pub get, 18 s). Gates 7 to 11 are the former 6 to 10.

## Merge (TL)
- 2026-11-27/28: `/code-review` (low): one finding, a false positive (the format gate does run when it is executed directly).
- Runs on GitHub (`macos-26`):

| Run | Commit | Cache | Result | Total | `bazel test //...` | sim build |
|---|---|---|---|---|---|---|
| 46057929555 | `2ba04a06` | cold | **FAIL** at the format gate: no `sky_engine` in a freshly cloned Flutter SDK; fixed in `46fb9581` | 27 min | 1496 s | — |
| 46067936968 | `46fb9581` | cold | **PASS**, all 10 gates; disk cache saved (1.3 GB) | 44 min | 1373 s | 963 s |
| 46072805534 | `e5b33b32` (adds gate 6, mcgen) | warm | **PASS**, all 11 gates | 25 min | 750 s | 403 s |
| 46075480500 | `6ad5dc02` (throwaway, deliberately failing test) | warm | **FAIL as intended**: the format aspect and the `result_test` assertion fail; the `ci-logs` artifact (16 KB) was uploaded; the branch was deleted after the run | 18 min | — | — |

- On this Mac, a fresh clone takes 341 s cold and 49 s warm. GitHub's runner is about 4× slower on the cold build.
- At 10× minutes for private-repo macOS, a warm run costs about 250 billed minutes and a cold one about 440.
- The TL merged `--no-ff`. On the merge result: `check` passed, 236/236 tests, lint clean, the format gate passed, and `tool/test/bazelw_test.sh` passed. The push to `main` starts the first CI run on `main`.
- 2026-11-28 (TL follow-up): docs-only pushes (`documents/**`, `**/*.md`) skip CI through `paths-ignore` on `push` and `pull_request`, because the TL's journal and STATUS pushes each started a warm macOS run (about 250 billed minutes). `actionlint` is clean. `workflow_dispatch` still runs on demand.
