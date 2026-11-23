# T-0020: `mc_config`, `mc_monitoring`, `mc_event_bus`, `mc_storage` (P1-03, minus `mc_media`)

| Field | Value |
|---|---|
| Status | In Review |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0020-core-utils` (from `origin/main` `1429119`+) |
| Created | 2026-11-23 |
| Depends on | T-0017 (`mc_prelude`, `mc_di`, merged) |
| Related | [plan 01 P1-03, D-11, D-22, catalogue rows](../plan/01-architecture-and-modules.md), R13 (no dart-defines), R15 (generator-read code is Flutter-free), ADR-0007 |

## Goal
The cross-cutting utilities the app shell and every feature need: typed per-environment config with no dart-defines (R13), Tide-style monitoring with console and in-memory sinks (D-11), an event bus, and file storage.

## Scope
- **In:**
  - `utility/mc_config`: `AppConfig` read once at boot from the bundled `app_config.json`. That file is selected by a Bazel build setting `--//tool/bazel/config:env=dev|e2e` (create `tool/bazel/config/` with the `string_flag` and the `config/<env>.json` files).
  - `utility/mc_monitoring`: **pure Dart**, Tide's `log` / `trackEvent` / `recordError` API, with console and in-memory sinks and an `McDIInitializer`. The Flutter error hooks are *not* here; they belong in `app_core` later.
  - `utility/mc_event_bus`: typed publish and subscribe (`DataChanged(topic)`).
  - `utility/mc_storage`: a key-value file store using `dart:io` under a given directory (no plugins, plan 01 C10).
  - A `BUILD.bazel` per package, a DI initializer per package where the plan says so, and `workspace:` entries in the root `pubspec.yaml`.
- **Out:** `mc_media` (conflicts with T-0018's `ApiImage`; follow-up), app wiring.

## Acceptance criteria
- **T-0020-AC1:** Given `--//tool/bazel/config:env=e2e` (latency 0 in `config/e2e.json`), then the bundled config yields `AppConfig.backend.latency == Duration.zero`, and `aquery` on the consuming target shows no `--dart-define`. Given `env=dev`, the dev values are read.
- **T-0020-AC2:** Given an in-memory sink, when `log`, `trackEvent` and `recordError` are called, then the sink holds the entries in order with their levels and attributes.
- **T-0020-AC3:** Given two subscribers to `favourites`, when `DataChanged('favourites')` is published, then each receives it exactly once; an unsubscribed listener receives nothing.
- **T-0020-AC4:** Given a file store, when a value is written and a new store opens the same directory, then the value reads back. A corrupt file yields a typed failure (`Result`), not a crash.
- **T-0020-AC5:** `mc_monitoring`, `mc_event_bus` and `mc_storage` import no Flutter (R15, checked by a test or by `mc_arch_check`). `tool/bazelw test //utility/...` and `build --config=lint //...` pass, and `mc_arch_check` reports OK.

## Log
- 2026-11-23: Created and dispatched.

## Outcome
Implemented `mc_config`, `mc_monitoring`, `mc_event_bus`, `mc_storage`, plus `tool/bazel/config/` (`string_flag env`, `dev|e2e|perf.json`, `app_config` genrule). Evidence: `documents/evidence/T-0020/engineer/`. Finding: F-0016.

| AC | Test | Result |
|---|---|---|
| AC1 | `mc_config:app_config_test`, `mc_config:bundled_config_test` (run with `env=e2e` and default dev); aquery: 0 `--dart-define` | PASS |
| AC2 | `mc_monitoring:monitoring_test` | PASS |
| AC3 | `mc_event_bus:event_bus_test` | PASS |
| AC4 | `mc_storage:file_store_test` | PASS |
| AC5 | `*:no_flutter_test` x3; `//utility/...` 11/11 uncached; `build --config=lint //...` OK; `mc_arch_check` OK | PASS |

Root changes: `pubspec.yaml` workspace list (+4 entries); `pubspec.lock` unchanged. Design: `ConfigDIInitializer(ConfigSource)`, `StorageDIInitializer(Directory)` and `MonitoringDIInitializer({sinks})` take app-supplied inputs; `EventBusDIInitializer` is const. Follow-up: `app_core` supplies the asset loader and Flutter error hooks; the app BUILD should bundle `//tool/bazel/config:app_config` as an asset; `mc_media` still open.
