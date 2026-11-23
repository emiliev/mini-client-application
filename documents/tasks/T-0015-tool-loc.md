# T-0015: `tool/loc`, the LOC counter (P2-02)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Sonnet, fresh; low-risk tooling) |
| Branch | `fleet/T-0015-tool-loc` |
| Created | 2026-11-23 |
| Depends on | — (Phase A, wave A1) |
| Related | [plan 02 §4, P2-02](../plan/02-generation-and-scale.md), ADR-0009, R1, R28, Q-010 |

## Goal
A Dart CLI implementing the D8 / R1 counting rule exactly. It's the gate for every scale rung.

## Scope
- **In:** `tool/loc/` (a Dart package run with `fvm dart`, using `package:analyzer`'s scanner as specified in plan 02 §4.1), the JSON schema `mc-loc/1`, a Markdown report, `--strict`, `--generated-root`, and a test corpus.
- **Out:** archetype data from `mcgen` specs (read it when present; tolerate its absence).
- **Files / areas:** `tool/loc/` only.

## Acceptance criteria
- **T-0015-AC1:** Given a corpus of fixture files with hand-computed expected counts (line and block comments, nested `/* /* */ */`, multi-line strings, doc comments, blank lines, code after a comment on the same line), when `tool/loc` runs, then every per-file count matches exactly.
- **T-0015-AC2:** Given files with generated suffixes (`*.g.dart`, `*.freezed.dart`, `*.config.dart`, `*.gr.dart`, generated l10n, a BDD `_test.dart` with a sibling `.feature`), then they're excluded from source and counted under `generated` only when `--generated-root` is given.
- **T-0015-AC3:** Given files under `app/`, `feature/`, `utility/`, `test/`, a testonly package, and `tool/`, then they land in `source.{hand,scaffold}`, `test` and `tooling` as the plan 02 §4.1 table says. Scaffold vs hand is decided from `.mcgen/manifest.json` hashes and keep regions; with no manifest, all source is `hand`.
- **T-0015-AC4:** Then the output is valid `mc-loc/1` JSON (per-module, per-tier, per-layer, histograms) plus a Markdown report, and two runs give byte-identical output.
- **T-0015-AC5:** Given a committed generated file under `--strict`, then the run fails naming it, unless the file is listed in `tool/build_runner_overlay/fallback.yaml` (R28).
- **T-0015-AC6:** `fvm dart analyze tool/loc` is clean and `fvm dart test tool/loc` passes. (Bazel wiring comes later.)

## Log
- 2026-11-23: Created and dispatched (wave A1).

## Outcome
_Pending._
