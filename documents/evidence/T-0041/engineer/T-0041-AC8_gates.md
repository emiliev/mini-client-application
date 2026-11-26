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
| coverage >= 90 % (touched packages) | **FAIL** |

- tests: Executed 16 out of 111 tests: 111 tests pass.
- coverage: == feature/comics/comics_details TOTAL 374/376 99.5% == app/wiring/publishing_wiring TOTAL 93/93 100.0% == feature/characters/characters_list TOTAL 219/219 100.0% == app/wiring/universe_wiring TOTAL 39/39 100.0% == utility/mc_formatters TOTAL 21/29 72.4% UNDER 90: utility/mc_formatters == utility/mc_fixtures_comics TOTAL 244/247 98.8% == utility/mc_fixtures_characters TOTAL 126/130 96.9% (threshold 90 %)

### coverage >= 90 % (touched packages) failed

```
package:universe_wiring/src/di/universe_wiring_di_initializer.dart: 6/6 100.0% missed=[]
package:universe_wiring/src/flows/character_details_placeholder_flow.dart: 11/11 100.0% missed=[]
package:universe_wiring/src/navigators/characters_list_navigator_impl.dart: 6/6 100.0% missed=[]
package:universe_wiring/src/routes/characters_routes.dart: 7/7 100.0% missed=[]
package:universe_wiring/src/routes/route_targets_impl.dart: 5/5 100.0% missed=[]
package:universe_wiring/universe_wiring.dart: 1/1 100.0% missed=[]
TOTAL 39/39 100.0%
== utility/mc_formatters
package:mc_formatters/src/formatters.dart: 13/13 100.0% missed=[]
package:mc_formatters/src/formatters_di_initializer.dart: 3/3 100.0% missed=[]
package:mc_formatters/src/money.dart: 5/13 38.5% missed=[35, 37, 38, 39, 41, 42, 44, 45]
TOTAL 21/29 72.4%
UNDER 90: utility/mc_formatters
== utility/mc_fixtures_comics
package:mc_fixtures_comics/src/data/universe.dart: 146/146 100.0% missed=[]
package:mc_fixtures_comics/src/domain.dart: 19/22 86.4% missed=[29, 66, 82]
package:mc_fixtures_comics/src/fixture_sets.dart: 4/4 100.0% missed=[]
package:mc_fixtures_comics/src/handlers/comics_handlers.dart: 75/75 100.0% missed=[]
TOTAL 244/247 98.8%
== utility/mc_fixtures_characters
package:mc_fixtures_characters/src/data/universe.dart: 57/57 100.0% missed=[]
package:mc_fixtures_characters/src/domain.dart: 7/8 87.5% missed=[17]
package:mc_fixtures_characters/src/fixture_sets.dart: 9/10 90.0% missed=[14]
package:mc_fixtures_characters/src/handlers/characters_handlers.dart: 53/55 96.4% missed=[135, 138]
TOTAL 126/130 96.9%
```

**FAIL T-0041-AC8-gates**
