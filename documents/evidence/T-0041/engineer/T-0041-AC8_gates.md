# T-0041-AC8: gates, codegen checks and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| fixtures check (T-0031-AC6) | PASS |
| relative API paths (T-0034-AC4) | PASS |
| T-0041-AC7_matches_build_runner | PASS |
| T-0041-AC7_cutoff | PASS |
| T-0041-AC7_generated_not_committed | PASS |
| T-0041-AC7_gen_l10n_parity | PASS |
| T-0032-AC6_matches_build_runner | PASS |
| T-0032-AC6_cutoff | PASS |
| T-0032-AC6_generated_not_committed | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 108 tests: 108 tests pass.
- coverage: == feature/comics/comics_details TOTAL 353/353 100.0% == app/wiring/publishing_wiring TOTAL 88/88 100.0% == feature/characters/characters_list TOTAL 216/216 100.0% == app/wiring/universe_wiring TOTAL 38/38 100.0% (threshold 90 %)

**PASS T-0041-AC8-gates**
