# Verification report — T-0015: `tool/loc` (P2-02)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23 (re-verification after review-fix rewrite)
- **Branch / commit verified:** `fleet/T-0015-tool-loc` @ `ad04b84` (`a17815f` → `2812b07` → `d204a75` → `ad04b84`). An earlier verification of the superseded `ab89473` is replaced by this report.
- **Simulator:** n/a (CLI tooling, no UI)
- **Verdict:** PASS

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Analyze | `fvm dart analyze .` (in `tool/loc`) | No issues found |
| Tests | `fvm dart test` (in `tool/loc`) | 25 passed, 0 failed |
| Tests from repo root | `fvm dart tool/loc/test/loc_test.dart` | 25 passed |
| Tests from `tool/loc/test` cwd | `fvm dart loc_test.dart` | 25 passed (fixtures independent of cwd) |
| Independent counting | 3 Verifier-written fixtures via the CLI | 11 (8 + 3 + 0), matches hand count; two runs byte-identical |
| Strict via CLI (git repo, tracked `foo.g.dart`) | `loc <dir> --strict` | exit 1, `FAIL: committed generated file (D7): utility/u/lib/foo.g.dart` |
| Strict with `tool/build_runner_overlay/fallback.yaml` | same | exit 0, counted as `generated.json = 1` |

## The 8 review fixes
| # | Fix | Evidence | Result |
|---|---|---|---|
| 1 | no `.dart_tool` in history | `git ls-files` has none; `git log --name-only a17815f..ad04b84` has none (only text mentions in the task file and the root `.gitignore` entry) | PASS |
| 2 | `--strict` uses `git ls-files` | `_gitFiles` runs `git ls-files -z --cached`; test `AC5 strict uses git ls-files` (untracked excluded unless requested); CLI: untracked `.g.dart` gave exit 0, after `git add` exit 1 | PASS |
| 3 | unowned tier files and unparseable pubspecs counted and warned | tests `files outside any module...` (synthetic `(unowned:utility)` module, warning, strict failure) and `unparseable pubspec.yaml...` | PASS |
| 4 | l10n scoped to `l10n.yaml` | test `l10n rule needs l10n.yaml and the configured output dir` (no yaml: counted as source; file outside the output dir: source) | PASS |
| 5 | malformed `.arb` or manifest does not crash | test `malformed .arb and manifest warn instead of crashing` (no crash, warnings, strict failures, counts kept) | PASS |
| 6 | `--generated-root` counts only first-party generator-kind files | test `generated root ignores external/ and non-generated copies` | PASS |
| 7 | combined `.g.dart` split by section | test `combined .g.dart is split by generator section` (json 2, retrofit 3) | PASS |
| 8 | fixtures independent of cwd | `Isolate.resolvePackageUri`; passes from the root and from `tool/loc/test` | PASS |

## Acceptance criteria
| AC | Mapped tests | Test really asserts the AC? | Result |
|---|---|---|---|
| T-0015-AC1 | 5 tests, exact per-file counts from hand-computed constants | yes; my independent fixtures (`'${/*x*/1}'`, raw `//` string, `'''` string, nested block comment then code, lone `}`, CRLF, empty file) agree | PASS |
| T-0015-AC2 | suffixes, l10n, BDD, generated-root, sections, l10n scoping | yes | PASS |
| T-0015-AC3 | tiers and buckets, manifest and keep regions, no manifest, unowned, bad pubspec | yes | PASS |
| T-0015-AC4 | JSON sections, histograms, byte-identical runs | yes; also confirmed via CLI | PASS |
| T-0015-AC5 | strict, git ls-files, fallback (all/partial), malformed inputs, non-git | yes; CLI process confirmed exit codes and file naming | PASS |
| T-0015-AC6 | analyze clean, 25 tests pass | re-run above | PASS |

D8 rule: `lib/count.dart` is scanner-based (`parseString`, walks `token.next`, skips `precedingComments`, marks every line a token spans, drops whitespace-only lines), as plan 02 §4.1 specifies.

## Test-integrity audit
- Tests deleted, skipped or weakened: none (17 grew to 25; all names contain `T-0015-AC<n>`).
- Lint suppressions added: none seen.
- Golden files updated: none.

## Issues found
1. (low) The `.mcgen/manifest.json` format (`{archetype, files: {path: {hash: sha256 of file minus keep-region bodies, ownership: managed|owned|ejected}}}`) is reasonable and consistent with plan 02 KD4 and §4.1, but is documented only in the task file. mcgen must implement the identical hash. Record it in a finding or ADR before mcgen lands.
2. (info) Outside git, `--strict` walks the tree, warns, and (in my run) did not fail on a `.g.dart` because nothing is "committed". This is consistent with the design, but CI must run strict inside a git work tree.
3. (info) Per-file counts are not in the JSON, only aggregates. Engineer-declared gaps outside the ACs: `--gate`, `diff`, isolates, `cloc` cross-check.

## Notes for the Tech Lead
PASS. Merge `fleet/T-0015-tool-loc` @ `ad04b84`, not my old `fleet/T-0015-verify`, which descends from the superseded `ab89473`.
