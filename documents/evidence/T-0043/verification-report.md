# Verification report — T-0043: `mc_fixtures_discovery`

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0043-fixtures-discovery` @ `996fb5e`
- **Simulator:** none needed (pure Dart package, no e2e)
- **Verdict:** PASS

## Gates re-run independently
`tool/checks/T-0043-AC5_gates.sh` (output in `verifier/AC5_gates.md`, Bazel output base `/tmp/mc-ob-T-0043-verifier`).

| Gate | Command | Result |
|---|---|---|
| Purity | closure of `//utility/mc_fixtures_discovery` (1352 targets), positive control `mc_fixtures_media` shows `sky_engine` | PASS: no Flutter markers |
| Registration | root `pubspec.yaml` | PASS |
| Fixtures check | 27 production targets scanned; positive control (own test) and negative control (dep added to `characters_list` BUILD) both detected | PASS |
| Tests | uncached discovery run | 4/4 PASS |
| Tests | `test //...` | 115/115 PASS |
| Lint | `build --config=lint //...` | PASS |
| Arch | `mc_arch_check` | PASS |
| Fork | `rules_fork.sh check` | PASS |
| l10n | `l10n_check` | PASS |
| Format | `dart format --set-exit-if-changed app feature spike utility tool/l10n_check tool/mc_arch_check` | PASS on re-run (see note) |
| Coverage | own lcov parser over the four `coverage.dat` files | 155/159 = **97.5 %** (domain 26/30, fixture_sets 3/3, handlers 47/47, index 65/65, normalize 14/14), matches the engineer's figure |

Note on format: the script's format gate reported FAIL in my fresh worktree (`AC5_gates.md` shows it), because the worktree had no `.dart_tool/package_config.json`: `package:mc_analysis` could not be resolved, so the formatter ignored the repo's style config and "changed" 56 files, almost all outside this task. After `fvm dart pub get --offline` the same command gives `0 changed` on all 552 files. This is an environment gap (the script does not run `pub get`), not a code defect; see issue 1.

After the script, `git status` showed the tree clean (the BUILD file used for the negative control was restored).

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / probe | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0043-AC1 | seed 42, same sequence on two backends | `search_test` T-0043-AC1 (3 tests); my `verifier/probe.dart.txt` with 8 requests on two backends: byte-identical | yes (raw body text compared) | PASS |
| T-0043-AC2 | ranking for `spi` and others | `ranking_test` (25 tests) and `search_test` (independent oracle for 6 queries); my probe: `spi` gives 152 characters then 400 comics, `iro`, `chr`; every result has the query as prefix, word-prefix or substring | yes: each tier pair is pinned against a contradicting title order; mutations M1, M2, M3 died | PASS |
| T-0043-AC2 (P1-10 AC5) | curated name hits both domains | `spindle` / `spi` returns `Spindle Alchemist` (character) and `Spindle Chronicles #1` (comic), characters first | yes | PASS |
| T-0043-AC3 | snapshots, resolvable ids, thumbnails | `provider_contract_test` (13 tests, 14 snapshots; every id resolves on its own detail endpoint for seeds 42 and 7; every thumbnail resolves to an asset file); M4 (edited snapshot) died | yes | PASS |
| T-0043-AC4 | validation | `search_test`, `fixture_sets_test` (25 tests); my probe (below) | yes | PASS |
| T-0043-AC5 | pure, registered, covered, gates | gates script (above) | yes, negative controls both fire | PASS |

AC4 probes (all as documented in `CONTRACT.md`):
- `q`: `a`, empty, missing, ` a `, `%CC%81%CC%81`, `e%CC%81`, `%C3%A9` all give 400 `query_too_short`; `éé` gives 200.
- `types`: `hero`, empty, `character,` and `Character` give 400 `invalid_parameter`; `comic,character` is served character-first.
- `limit`: 0, 101, -1, `abc`, empty give 400; 1 and 100 give 200 (per group).
- `empty` and `server_error` sets: same status and byte-identical body as the scenario of the same name on `q=spi`, suggestions, a short `q` and a bad `types`. The empty set still validates (400s); `server_error` answers 500 `injected_failure` for every request, even invalid ones.
- Folding: `foldText('Știința') == foldText('stiinta') == 'stiinta'`; `Việt` folds to `viet`; `%C8%98tiin%C8%9Ba` and `stiinta` give the same (zero-hit) result because no title uses the word.

## Mutations (10, mine) and review fixes
All 10 killed (`verifier/mutations.log`): prefix and word-prefix tier swaps (M1, M2), title tie-break reversed (M3), snapshot edit (M4), group order (M6), plus R1 (folded length), R2 (code-point boundary), R3 (wider folding), R4 (comma-below fold), R5 (entry type check). Three first attempts (`if (false)` variants) failed the lint build and were redone as lint-clean mutants; they were not counted as kills.

## Test-integrity audit
- Tests deleted, skipped or weakened: none (the diff against `origin/main` only adds files; `skip` matches are Dart `Iterable.skip`).
- Lint suppressions added: none (`// ignore:` grep of the diff is empty).
- Golden files updated: none.
- Diff vs `origin/main`: 36 files, all in `utility/mc_fixtures_discovery`, the root `pubspec.yaml` (one workspace line), `tool/checks/T-0043-AC5_gates.sh`, the task file and engineer evidence. Nothing unrelated. No lock file changed.
- Every AC has `T-0043-ACn` tests (AC1 3, AC2 42, AC3 13, AC4 17 mentions).
- Trademark check: the generated vocabulary (about 90 words: Alchemist, Spindle, Ember, Zephyr, ...) is generic; no real character or title found.

## Visual acceptance
Not applicable.

## Issues found
1. (Low, tooling) `tool/checks/T-0043-AC5_gates.sh`, the `dart format` gate: it fails in a worktree that has not run `pub get` (unresolved `mc_analysis` include changes formatting of 56 unrelated files). Same pattern as the T-0038 script. Run `fvm dart pub get --offline` first, or have the script do it. Not a defect in the delivered code.

## Notes for the Tech Lead
- No code defects found. Verdict PASS at `996fb5e`.
- Merge note: I did not change code; this commit adds only the report and `documents/evidence/T-0043/verifier/` (gates output, my mutation script and log, my probe script).
- The gates output file `verifier/AC5_gates.md` shows the format FAIL from the missing `pub get`; the re-run with `pub get` is PASS as stated above.
