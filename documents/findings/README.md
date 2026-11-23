# Findings

A finding is knowledge we earned and don't want to earn twice: environment gotchas, bug root causes, spike results, benchmarks, library behaviour, dead ends.

**Process:** copy [../templates/finding.md](../templates/finding.md) to `F-XXXX-<slug>.md` using the next free number. Crew may create findings freely; the Tech Lead adds them to the index below.

## Index
| ID | Title | Type | Date | Impact |
|---|---|---|---|---|
| [F-0001](F-0001-environment-survey.md) | Development environment survey | Environment | 2026-11-22 | Agents must use `fvm flutter`; no git remote yet (superseded by F-0002) |
| [F-0002](F-0002-github-remote-access.md) | GitHub remote access | Environment | 2026-11-22 | `origin` over HTTPS via keychain; no SSH, no `gh`, so no CLI PRs |
| [F-0003](F-0003-marvel-api-unavailable.md) | The official Marvel API is effectively unavailable | Spike | 2026-11-22 | `mocked_backend` contract is our own design; no real-API swap target |
| [F-0004](F-0004-ios-verification-pipeline.md) | The iOS verification pipeline works end to end on this Mac | Spike | 2026-11-22 | All ADR-0006 layers proven; e2e 41 s cold / 13 s warm; goldens need real fonts; create simulators, never clone |
| [F-0005](F-0005-bash-background-jobs-ignore-sigint.md) | Bash background jobs ignore SIGINT; traps wait for foreground children | Lesson | 2026-11-23 | Use `cmd & wait $!`, process groups, and ignore INT/TERM during teardown |
| [F-0006](F-0006-bazel-version-via-bazelisk.md) | Bazel 9.3.0 runs through the unlinked Homebrew bazelisk; `tool/bazelw` is mandatory | Environment | 2026-11-23 | Always `tool/bazelw` |
| [F-0007](F-0007-codegen-summaries-crash-over-flutter-closure.md) | rules_dart passes analyzer summaries to codegen over a Flutter closure, and the shim crashes | Bug root cause | 2026-11-23 | **Upstream bug.** Workaround: `@flutter_sky_engine//:sky_engine` in the codegen deps; go_router stays on Bazel |
| [F-0008](F-0008-bazel-9-2-tooling-gaps.md) | Bazel 9.2 tooling gaps: no `analyze-profile`, no `--verbose_explanations`, concatenated JSON exec log | Environment | 2026-11-23 | Perf ingestion and the AC5 reference changed; plan 04 §6.3 needs a refresh (P-020) |
| [F-0009](F-0009-toolchain-bring-up-facts.md) | Toolchain bring-up facts (SDK fetch, H-SDK, outlines, caches) | Spike | 2026-11-23 | First build 15 min; outline cutoff works on Dart 3.13.5 |
| [F-0010](F-0010-h-cfgdup-measured.md) | H-CFGDUP measured: codegen runs once per configuration | Benchmark | 2026-11-23 | 3/3 codegen duplicated; 12/32 kernels built in two variants |
| [F-0011](F-0011-codegen-language-version-and-overlay-pins.md) | Codegen equals build_runner's only with `language_version` set | Lesson | 2026-11-23 | buildgen must emit `language_version`; the overlay pins analyzer and source_helper |
| [F-0012](F-0012-test-analyze-format-top-level-only.md) | `bazel test` analyzes and format-checks only the test target | Lesson | 2026-11-23 | Use `build --config=lint //...` for full coverage |
| [F-0013](F-0013-lint-and-runfiles-facts.md) | Lint and runfiles facts: Tide rules on Dart 3.13.5, aspect vs `dart analyze` gap | Lesson | 2026-11-23 | `mc_analysis` carries 21 rules; one aspect miss under investigation (P-030) |
| [F-0014](F-0014-goldens-under-bazel-flutter-test.md) | Goldens under Bazel `flutter_test`: read path, update command, fonts and icons | Lesson | 2026-11-23 | Real fonts via the golden harness; MaterialIcons resolved via runfiles or an env var |
| [F-0015](F-0015-mocked-backend-bazel-test-gotchas.md) | Mocked backend Bazel test and data-file gotchas | Lesson | 2026-11-23 | Fixture assets and test data under Bazel runfiles |
| [F-0016](F-0016-config-select-and-runfiles-in-tests.md) | Selecting a Bazel build setting inside `dart_test` | Lesson | 2026-11-23 | Per-env config without dart-defines (R13) |
| [F-0017](F-0017-api-client-retry-and-dart-test-deps.md) | Dio interceptor order, error shapes, `dart_test` against the mocked backend | Lesson | 2026-11-24 | API client design notes |
| [F-0019](F-0019-dio-cycle-merge-pulls-flutter-into-pure-dart.md) | The dio/dio_web_adapter cycle merge pulls Flutter into pure-Dart closures | Bug root cause | 2026-11-24 | **Upstream.** Workaround: `cycle_breaks`; keeps codegen summaries on |
