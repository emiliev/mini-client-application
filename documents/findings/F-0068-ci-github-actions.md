# F-0068: CI on GitHub Actions (Bazel on a macOS runner)

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0068)
- **Type:** Benchmark
- **Related:** T-0068, T-0005 (superseded), ADR-0015, F-0001, F-0002, F-0006

## Summary
`tool/ci/ci.sh` runs eleven gates (gate 6, `tool/mcgen` pub get, analyze and test, was added after T-0065; local 27 s) (the ADR-0015 merge gates minus the flake check) and `.github/workflows/ci.yml` runs it on `macos-26` for pushes to `main` and `fleet/**`, pull requests and manual runs. On a fresh clone of the branch, with its own Bazel output base and empty Bazel caches, the whole script took **341 s** (about 6 min). With the same disk and repository caches and a new output base it took **49 s**. The Bazel caches are 3.5 GB (repository) plus 1.3 GB (disk) plus 0.2 GB (bazelisk), so they fit the 10 GB Actions cache limit. The GitHub-hosted numbers are filled in after the first runs (see the task file).

## Evidence
Local fresh clone (`git clone` of the branch to a temp dir, `MC_BAZEL_STARTUP=--output_base=...`, `MC_CI_CACHE_DIR=...`, Apple Silicon Mac, Xcode 26.2, warm bazelisk and pub caches):

| # | Gate | Cold caches (s) | Warm disk cache, new output base (s) |
|---|---|---|---|
| 1 | `rules_fork.sh check` | 1 | 1 |
| 2 | `bazel test --config=ci //...` (223 tests pass) | 251 | 15 |
| 3 | `bazel build --config=ci --config=lint //...` | 3 | 5 |
| 4 | `mc_arch_check` | 3 | 3 |
| 5 | format gate | 5 | 2 |
| 6 | `l10n_check` | 4 | 3 |
| 7 | flow_builder provenance | 1 | 1 |
| 8 | no direct overlays | 5 | 3 |
| 9 | sim app build | 67 | 15 |
| 10 | app-tagged tests (none exist) | 1 | 1 |
| | **total** | **341** | **49** |

- Cache sizes after the cold run: repository cache **3.5 GB**, disk cache **1.3 GB**, bazelisk download cache 183 MB, Bazel output base 2.0 GB (not cached in CI). `actions/cache` compresses, so the stored size is smaller.
- The lockfile did not change (`git status` clean after the run, `--lockfile_mode=error` is part of `--config=ci`).
- Format gate in CI mode (no `fvm`, Flutter 3.47.7 `bin` first on PATH, `MC_DART=dart`, `.dart_tool` removed): PASS in 10 s (online `dart pub get` plus 1189 files, 0 changed).
- `actionlint` (Homebrew) reports nothing for `ci.yml`; every third-party action is pinned to a SHA with its version in a comment: `actions/checkout` v7.0.1, `actions/cache` v6.1.0 (also `/restore` and `/save`), `actions/upload-artifact` v7.0.2.

## What differs on a clean runner (handled)
- **bazelisk path:** `tool/bazelw` hard-coded Homebrew's unlinked bazelisk. It now falls back to a `bazelisk` on PATH (the runner image ships one; the workflow installs it when missing). `MC_BAZELISK` still wins.
- **FVM:** the format gate called `fvm dart`. It now runs `$MC_DART` when set (with an online `pub get`); the workflow clones Flutter at the `.fvmrc` version into `~/flutter-sdk` (cached) and sets `MC_DART=dart`. It needs a Flutter SDK, not only Dart, because the workspace has Flutter members.
- **Caches:** `.bazelrc` already points the disk and repository caches at `~/.cache/mc-bazel`, which is the path the workflow caches. `MC_CI_CACHE_DIR` overrides it for cold measurements.
- **Fresh Flutter clone (run 1 failure):** `dart pub get` fails on a just-cloned SDK (`sky_engine from sdk ... could not find package sky_engine`) because `bin/cache/pkg/sky_engine` is only downloaded by `flutter` itself. `flutter --version` does not fetch it; `flutter pub get` and `flutter precache --universal` do. Fix: the workflow runs `flutter precache --universal` after the clone or cache restore (and asserts the directory exists), and sets `MC_PUB_GET="flutter pub get"` so the format gate initialises the SDK itself. Reproduced and verified locally with a fresh 3.47.7 clone. The Flutter cache path `~/flutter-sdk` includes `bin/cache`.
- **Network:** gate 7 (pub.dev archive) and `rules_fork.sh check` (clones the pinned rules repos) need network; the runner has it.

## Cost and cache plan
- Private-repo macOS minutes bill at 10x. A warm run should take about 5 to 10 minutes of setup plus the build (the local warm run was 49 s of gates); a cold run about 10 to 15 minutes if the runner is as fast as this Mac (it has fewer cores, expect up to 2x). Real numbers: see the task file.
- Cache layout: the repository cache and bazelisk are one entry per lockfile (about 3.7 GB uncompressed). The disk cache (1.3 GB) is restored from the newest earlier entry and saved under a per-commit key on pushes only, so entries do not pile up past the 10 GB cap (oldest evicted first). Branch caches are scoped: `fleet/**` and PR runs can read `main`'s caches.
- Watch the cache size in the repo's Actions > Caches page; if the disk cache grows, trim it or key it on the week.

## Implications / actions
- A red `main` is visible in the README badge and in the Actions tab.
- Gate 2 can pass from cached test results (the disk cache holds test actions). That is the intent; use `MC_CI_CACHE_DIR` to force a cold run locally.
- Out of scope, still open: simulator e2e in CI, branch protection, a remote cache.
