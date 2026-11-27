# T-0050-AC4: gates, codegen checks and coverage

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
| T-0048-AC7_matches_build_runner | PASS |
| T-0048-AC7_cutoff | PASS |
| T-0048-AC7_generated_not_committed | PASS |
| T-0048-AC7_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | **FAIL** |

- tests: Executed 31 out of 146 tests: 146 tests pass.
- coverage: == utility/mc_api_auth TOTAL 124/124 100.0% == utility/mc_session TOTAL 92/92 100.0% == utility/mc_forms TOTAL 286/286 100.0% == utility/mc_test_steps TOTAL 10/308 3.2% UNDER 90: utility/mc_test_steps == feature/comics/comics_details TOTAL 398/398 100.0% == feature/library/library_reading_list_editor TOTAL 734/743 98.8% (threshold 90 %)

### coverage >= 90 % (touched packages) failed

```
package:comics_details/src/presentation/widget/failure_message.dart: 5/5 100.0% missed=[]
package:comics_details/src/presentation/widget/favourite_toggle.dart: 25/25 100.0% missed=[]
TOTAL 398/398 100.0%
== feature/library/library_reading_list_editor
package:library_reading_list_editor/src/di/di_initializer.dart: 3/3 100.0% missed=[]
package:library_reading_list_editor/src/domain/model/comic_id.dart: 1/1 100.0% missed=[]
package:library_reading_list_editor/src/domain/model/reading_list.dart: 13/13 100.0% missed=[]
package:library_reading_list_editor/src/domain/model/reading_list_dto.dart: 14/14 100.0% missed=[]
package:library_reading_list_editor/src/domain/model/reading_list_id.dart: 1/1 100.0% missed=[]
package:library_reading_list_editor/src/domain/model/reading_list_mapper.dart: 26/26 100.0% missed=[]
package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart: 28/28 100.0% missed=[]
package:library_reading_list_editor/src/flow/reading_list_editor_flow.dart: 13/13 100.0% missed=[]
package:library_reading_list_editor/src/presentation/bloc/comic_picker_bloc.dart: 28/29 96.6% missed=[31]
package:library_reading_list_editor/src/presentation/bloc/comic_picker_event.dart: 4/4 100.0% missed=[]
package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_bloc.dart: 166/166 100.0% missed=[]
package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_event.dart: 16/16 100.0% missed=[]
package:library_reading_list_editor/src/presentation/form/reading_list_form.dart: 43/43 100.0% missed=[]
package:library_reading_list_editor/src/presentation/page/comics_page.dart: 93/95 97.9% missed=[72, 77]
package:library_reading_list_editor/src/presentation/page/details_page.dart: 102/102 100.0% missed=[]
package:library_reading_list_editor/src/presentation/page/review_page.dart: 93/96 96.9% missed=[97, 98, 109]
package:library_reading_list_editor/src/presentation/widget/comic_row.dart: 27/27 100.0% missed=[]
package:library_reading_list_editor/src/presentation/widget/editor_step_bar.dart: 23/23 100.0% missed=[]
package:library_reading_list_editor/src/presentation/widget/messages.dart: 15/18 83.3% missed=[14, 29, 39]
package:library_reading_list_editor/src/presentation/widget/reading_order_row.dart: 25/25 100.0% missed=[]
TOTAL 734/743 98.8%
```

**FAIL T-0050-AC4-gates**
