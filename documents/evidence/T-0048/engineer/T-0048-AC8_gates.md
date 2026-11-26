# T-0048-AC8: gates, codegen checks and coverage

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
| T-0048-AC7_matches_build_runner | PASS |
| T-0048-AC7_cutoff | PASS |
| T-0048-AC7_generated_not_committed | PASS |
| T-0048-AC7_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 137 tests: 137 tests pass.
- coverage: == feature/library/library_reading_list_editor TOTAL 768/788 97.5% == app/wiring/library_wiring TOTAL 37/37 100.0% == app/wiring/app_core TOTAL 339/353 96.0% == app/wiring/publishing_wiring TOTAL 47/47 100.0% (threshold 90 %)

**PASS T-0048-AC8-gates**
