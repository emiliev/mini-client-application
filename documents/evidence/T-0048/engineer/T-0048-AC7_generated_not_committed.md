# T-0048-AC7: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/library/library_reading_list_editor`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| retrofit client | `lib/src/domain/api/reading_list_editor_api.g.dart` | yes | yes |
| json part | `lib/src/domain/model/reading_list_dto.g.dart` | yes | yes |
| freezed (DTO) | `lib/src/domain/model/reading_list_dto.freezed.dart` | yes | yes |
| freezed (domain) | `lib/src/domain/model/reading_list.freezed.dart` | yes | yes |
| freezed (flow state) | `lib/src/flow/reading_list_editor_flow_state.freezed.dart` | yes | yes |
| freezed (editor bloc state) | `lib/src/presentation/bloc/reading_list_editor_bloc.freezed.dart` | yes | yes |
| freezed (picker bloc state) | `lib/src/presentation/bloc/comic_picker_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard | `lib/src/presentation/bloc/reading_list_editor_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/reading_list_editor_l10n.dart` | yes | yes |
| gen-l10n (de) | `lib/src/l10n/reading_list_editor_l10n_de.dart` | yes | yes |
| BDD test | `test/feature/reading_list_editor_create_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/reading_list_editor_edit_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/reading_list_editor_races_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/reading_list_editor_l10n_test.dart` | yes | n/a (bazel-out only) |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

Hand-written paths the scoped ignore rules must leave visible:

| File | git |
|---|---|
| `test/feature/helpers_test.dart` | visible |
| `lib/src/app.config.dart` | visible |
| `test/feature/step/i_open_the_reading_list_editor.dart` | visible |

All declared outputs of the package's generator targets (22):

```
lib/src/di/di_initializer.config.dart
lib/src/domain/api/reading_list_editor_api.g.dart
lib/src/domain/api/reading_list_editor_api.injectable.json
lib/src/domain/api/reading_list_editor_api.retrofit.g.part
lib/src/domain/model/reading_list.freezed.dart
lib/src/domain/model/reading_list_dto.freezed.dart
lib/src/domain/model/reading_list_dto.g.dart
lib/src/domain/model/reading_list_dto.json_serializable.g.part
lib/src/domain/repository/reading_list_editor_repository.injectable.json
lib/src/flow/reading_list_editor_flow_state.freezed.dart
lib/src/l10n/reading_list_editor_l10n.dart
lib/src/l10n/reading_list_editor_l10n_de.dart
lib/src/l10n/reading_list_editor_l10n_en.dart
lib/src/presentation/bloc/comic_picker_bloc.freezed.dart
lib/src/presentation/bloc/comic_picker_bloc.injectable.json
lib/src/presentation/bloc/reading_list_editor_bloc.freezed.dart
lib/src/presentation/bloc/reading_list_editor_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/reading_list_editor_create_test.dart
test/feature/reading_list_editor_edit_test.dart
test/feature/reading_list_editor_l10n_test.dart
test/feature/reading_list_editor_races_test.dart
```

**PASS T-0048-AC7-not-committed**
