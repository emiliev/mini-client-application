# T-0049-AC4: gates and coverage

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
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 146 tests: 146 tests pass.
- coverage: == app/mini_client TOTAL 104/109 95.4% == app/wiring/app_core TOTAL 397/412 96.4% == app/wiring/library_wiring TOTAL 39/39 100.0% == app/wiring/publishing_wiring TOTAL 47/47 100.0% == app/wiring/universe_wiring TOTAL 39/39 100.0% == app/wiring/discovery_wiring TOTAL 22/22 100.0% (threshold 90 %)

**PASS T-0049-AC4-gates**
