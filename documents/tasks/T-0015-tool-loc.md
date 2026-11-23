# T-0015: `tool/loc`, the LOC counter (P2-02)

| Field | Value |
|---|---|
| Status | In Review |
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
- 2026-11-23: Engineer built `tool/loc`, fixtures and 17 tests; analyze clean; evidence recorded.
- 2026-11-23: Fixed 8 `/code-review` findings (below). Amended the first commit so `tool/loc/.dart_tool/` never enters branch history; root `.gitignore` added. 25 tests pass.

## Review-fix map (test names start with the AC ID)
1. `.dart_tool` purged from history (amend), root `.gitignore` (`.dart_tool/ build/ bazel-* .fvm/flutter_sdk coverage/ *.iml .idea/`).
2. Files from `git ls-files` (tracked only), `--include-untracked`, walk plus warning outside git: `T-0015-AC5 strict uses git ls-files...`, `T-0015-AC5 outside git it walks the tree and warns`.
3. Unowned tier files go to synthetic `(unowned:<tier>)`, warn, fail strict; unparseable pubspec likewise: `T-0015-AC3 files outside any module...`, `T-0015-AC3 unparseable pubspec.yaml...`.
4. l10n needs `l10n.yaml` and its output dir: `T-0015-AC2 l10n rule needs l10n.yaml and the configured output dir`.
5. Malformed `.arb` / manifest warn, fail strict, no crash: `T-0015-AC5 malformed .arb and manifest warn...`.
6. `--generated-root` only generator kinds under tier paths: `T-0015-AC2 generated root ignores external/...`.
7. Combined `.g.dart` split by section header: `T-0015-AC2 combined .g.dart is split by generator section`.
8. Fixtures resolved via `Isolate.resolvePackageUri`. Pass: `fvm dart test` in `tool/loc` (25) and `fvm dart tool/loc/test/loc_test.dart` from the repo root (25). `fvm dart test tool/loc` from the root cannot run: dart needs a pubspec in cwd, and the repo root has none yet.
Nits: `MixinDeclaration` nodes plus `with_applications`; README with the manifest format.

## AC to test map
All in `tool/loc/test/loc_test.dart`.
| AC | Tests |
|---|---|
| T-0015-AC1 | `T-0015-AC1 line comments...`, `nested block comments...`, `multi-line strings...`, `doc comments and blank lines`, `imports and mixins are tallied` |
| T-0015-AC2 | `T-0015-AC2 generated suffixes, l10n and BDD are excluded`, `generated bucket only with --generated-root` |
| T-0015-AC3 | `T-0015-AC3 tiers, test, testonly and tooling buckets`, `manifest hashes and keep regions split hand/scaffold`, `without a manifest everything is hand` |
| T-0015-AC4 | `T-0015-AC4 valid mc-loc/1 JSON...`, `fan-in/out histograms...`, `two runs are byte-identical...` |
| T-0015-AC5 | `T-0015-AC5 committed generated files fail naming each file`, `non-strict never fails`, `files in fallback.yaml pass and count as generated`, `a fallback listing only some files still fails the rest` |
| T-0015-AC6 | `fvm dart analyze tool/loc` (No issues found) and `fvm dart test` (17 passed) |

## Outcome
Implemented `tool/loc/` (package `loc`; `bin/loc.dart`, `lib/count.dart` = D8 scanner, `lib/loc.dart` = walk, classify, aggregate, JSON and Markdown). Run: `fvm dart run tool/loc/bin/loc.dart <root> [--json f] [--md f] [--strict] [--generated-root d] [--stamp s] [--commit sha]`. Exit 1 under `--strict` when a committed generated file is not in `fallback.yaml`.

**Tests:** 17 pass (`cd tool/loc && fvm dart test`); `fvm dart analyze tool/loc` clean. Fixtures are stored with a `.fixture` suffix (stripped on copy to a temp dir) so they are neither analysed nor counted as tooling.

**Evidence:** `documents/evidence/T-0015/engineer/repo-loc.{json,md}`: two runs byte-identical. This repo has no app/feature/utility modules yet: source 0, tooling 876 lines.

**Assumptions the plan left open (flag for review):**
- Manifest format (not specified elsewhere): `<module>/.mcgen/manifest.json` = `{"archetype": "...", "files": {"<path in module>": {"hash": "<sha256>", "ownership": "managed|owned|ejected"}}}`. Hash is sha256 of the file with keep-region bodies (lines between `// mcgen:keep id` and `// mcgen:end id`) removed. Listed, non-ejected, hash match = scaffold (keep lines hand); anything else = hand. Archetype falls back to `mcgen.yaml`, then `unknown`.
- Module = a `pubspec.yaml` under `app|feature|utility`; testonly = `testonly: true` in the pubspec or name `mc_test_utils`.
- `fallback.yaml`: any `.dart` path string anywhere in the YAML counts as listed.
- `.g.dart` is `retrofit` if it mentions `RestClient`/`retrofit`, else `json`.
- Not done: `--gate <rung>` / `gates.yaml` (gates field is emitted with pass/failures from strict only), `loc diff a b`, per-core isolates, the `cloc` cross-check finding. See follow-ups.

**Follow-ups:** gate + diff subcommands; isolates for the 1M/30 s target; cloc cross-check finding; CLI-level (process) test of exit code.
