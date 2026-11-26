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
| coverage >= 100.1 % (touched packages) | **FAIL** |

- tests: Executed 0 out of 108 tests: 108 tests pass.
- coverage: == feature/comics/comics_details TOTAL 353/353 100.0% UNDER 100.1: feature/comics/comics_details == app/wiring/publishing_wiring TOTAL 88/88 100.0% UNDER 100.1: app/wiring/publishing_wiring == feature/characters/characters_list TOTAL 216/216 100.0% UNDER 100.1: feature/characters/characters_list == app/wiring/universe_wiring TOTAL 38/38 100.0% UNDER 100.1: app/wiring/universe_wiring (threshold 100.1 %)

### coverage >= 100.1 % (touched packages) failed

```
package:characters_list/src/domain/model/characters_query.dart: 1/1 100.0% missed=[]
package:characters_list/src/domain/model/comic_id.dart: 1/1 100.0% missed=[]
package:characters_list/src/domain/repository/characters_list_repository.dart: 14/14 100.0% missed=[]
package:characters_list/src/flow/characters_list_flow.dart: 13/13 100.0% missed=[]
package:characters_list/src/presentation/bloc/character_preview_bloc.dart: 7/7 100.0% missed=[]
package:characters_list/src/presentation/bloc/characters_list_bloc.dart: 34/34 100.0% missed=[]
package:characters_list/src/presentation/bloc/characters_list_event.dart: 7/7 100.0% missed=[]
package:characters_list/src/presentation/bloc/related_comics_bloc.dart: 15/15 100.0% missed=[]
package:characters_list/src/presentation/page/character_preview_page.dart: 27/27 100.0% missed=[]
package:characters_list/src/presentation/page/characters_list_page.dart: 35/35 100.0% missed=[]
package:characters_list/src/presentation/widget/character_tile.dart: 7/7 100.0% missed=[]
package:characters_list/src/presentation/widget/failure_message.dart: 5/5 100.0% missed=[]
package:characters_list/src/presentation/widget/related_comics.dart: 29/29 100.0% missed=[]
TOTAL 216/216 100.0%
UNDER 100.1: feature/characters/characters_list
== app/wiring/universe_wiring
package:universe_wiring/src/di/di_initializer.dart: 3/3 100.0% missed=[]
package:universe_wiring/src/di/universe_wiring_di_initializer.dart: 5/5 100.0% missed=[]
package:universe_wiring/src/flows/character_details_placeholder_flow.dart: 11/11 100.0% missed=[]
package:universe_wiring/src/navigators/characters_list_navigator_impl.dart: 6/6 100.0% missed=[]
package:universe_wiring/src/routes/characters_routes.dart: 7/7 100.0% missed=[]
package:universe_wiring/src/routes/route_targets_impl.dart: 5/5 100.0% missed=[]
package:universe_wiring/universe_wiring.dart: 1/1 100.0% missed=[]
TOTAL 38/38 100.0%
UNDER 100.1: app/wiring/universe_wiring
```

**FAIL T-0041-AC8-gates**
