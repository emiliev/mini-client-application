# T-0032-AC7: gates and coverage

| Gate | Result |
|---|---|
| test //... (T-0032 packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % | **FAIL** |

- tests: Executed 0 out of 75 tests: 75 tests pass.
- characters_list coverage: TOTAL 160/180 88.9% (threshold 90 %)

### coverage >= 90 % failed

```
  /private/tmp/mc-ob-T-0032-verifier/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/feature/characters/characters_list/contract_test/coverage.dat
//feature/characters/characters_list:bdd_test                            PASSED in 2.6s
  /private/tmp/mc-ob-T-0032-verifier/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/feature/characters/characters_list/bdd_test/coverage.dat
//feature/characters/characters_list:flow_scope_test                     PASSED in 1.3s
  /private/tmp/mc-ob-T-0032-verifier/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/feature/characters/characters_list/flow_scope_test/coverage.dat
//feature/characters/characters_list:golden_test                         PASSED in 1.6s
  /private/tmp/mc-ob-T-0032-verifier/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/feature/characters/characters_list/golden_test/coverage.dat

Executed 3 out of 5 tests: 5 tests pass.
There were tests whose specified size is too big. Use the --test_verbose_timeout_warnings command line option to see which ones these are.
package:characters_list/src/di/di_initializer.dart: 3/3 100.0% missed=[]
package:characters_list/src/domain/model/character_dto.dart: 4/4 100.0% missed=[]
package:characters_list/src/domain/model/character_id.dart: 1/1 100.0% missed=[]
package:characters_list/src/domain/model/character_mapper.dart: 11/11 100.0% missed=[]
package:characters_list/src/domain/model/characters_query.dart: 1/1 100.0% missed=[]
package:characters_list/src/domain/repository/characters_list_repository.dart: 8/8 100.0% missed=[]
package:characters_list/src/flow/characters_list_flow.dart: 17/17 100.0% missed=[]
package:characters_list/src/presentation/bloc/character_preview_bloc.dart: 7/7 100.0% missed=[]
package:characters_list/src/presentation/bloc/characters_list_bloc.dart: 34/34 100.0% missed=[]
package:characters_list/src/presentation/bloc/characters_list_event.dart: 7/7 100.0% missed=[]
package:characters_list/src/presentation/page/character_preview_page.dart: 19/19 100.0% missed=[]
package:characters_list/src/presentation/page/characters_list_page.dart: 36/36 100.0% missed=[]
package:characters_list/src/presentation/widget/character_tile.dart: 7/7 100.0% missed=[]
package:characters_list/src/presentation/widget/failure_message.dart: 5/25 20.0% missed=[15, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35]
TOTAL 160/180 88.9%
```

**FAIL T-0032-AC7-gates**
