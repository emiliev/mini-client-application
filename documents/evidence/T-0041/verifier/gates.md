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
| T-0041-AC1_fixtures_closure | PASS |
| T-0041-AC7_matches_build_runner | PASS |
| T-0041-AC7_cutoff | PASS |
| T-0041-AC7_generated_not_committed | PASS |
| T-0041-AC7_gen_l10n_parity | PASS |
| T-0032-AC6_matches_build_runner | PASS |
| T-0032-AC6_cutoff | PASS |
| T-0032-AC6_generated_not_committed | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 111 tests: 111 tests pass.
- coverage: == feature/comics/comics_details TOTAL 376/376 100.0% == app/wiring/publishing_wiring TOTAL 93/93 100.0% == feature/characters/characters_list TOTAL 219/219 100.0% == app/wiring/universe_wiring TOTAL 39/39 100.0% == utility/mc_formatters TOTAL 29/29 100.0% == utility/mc_fixtures_comics TOTAL 244/247 98.8% == utility/mc_fixtures_characters TOTAL 126/130 96.9% (threshold 90 %)

**PASS T-0041-AC8-gates**
