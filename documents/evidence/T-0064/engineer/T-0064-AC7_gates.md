# T-0064-AC7: gates, codegen checks and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format (format_gate.sh) | PASS |
| l10n_check | PASS |
| fixtures check (T-0031-AC6) | PASS |
| relative API paths (T-0034-AC4) | PASS |
| T-0064-AC7_matches_build_runner | PASS |
| T-0064-AC7_cutoff | PASS |
| T-0064-AC7_generated_not_committed | PASS |
| T-0064-AC7_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 210 tests: 210 tests pass.
- coverage: == feature/trivia/trivia_quiz TOTAL 1039/1051 98.9% == app/wiring/chronicle_wiring TOTAL 40/40 100.0% == app/wiring/app_core TOTAL 486/508 95.7% == utility/mc_fixtures_editorial TOTAL 468/470 99.6% (threshold 90 %)

**PASS T-0064-AC7-gates**
