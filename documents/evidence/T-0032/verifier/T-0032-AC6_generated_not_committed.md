# T-0032-AC6: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/characters/characters_list`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| retrofit client | `lib/src/domain/api/characters_list_api.g.dart` | yes | yes |
| json part | `lib/src/domain/model/character_dto.g.dart` | yes | yes |
| freezed (DTO) | `lib/src/domain/model/character_dto.freezed.dart` | yes | yes |
| freezed (domain) | `lib/src/domain/model/character.freezed.dart` | yes | yes |
| freezed (flow state) | `lib/src/flow/characters_list_flow_state.freezed.dart` | yes | yes |
| freezed (bloc state) | `lib/src/presentation/bloc/characters_list_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard | `lib/src/presentation/bloc/characters_list_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/characters_list_l10n.dart` | yes | yes |
| BDD test | `test/feature/characters_list_test.dart` | yes | yes |
| BDD test | `test/feature/characters_list_paging_test.dart` | yes | yes |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

All declared outputs of the package's generator targets (19):

```
lib/src/di/di_initializer.config.dart
lib/src/domain/api/characters_list_api.g.dart
lib/src/domain/api/characters_list_api.injectable.json
lib/src/domain/api/characters_list_api.retrofit.g.part
lib/src/domain/model/character.freezed.dart
lib/src/domain/model/character_dto.freezed.dart
lib/src/domain/model/character_dto.g.dart
lib/src/domain/model/character_dto.json_serializable.g.part
lib/src/domain/repository/characters_list_repository.injectable.json
lib/src/flow/characters_list_flow_state.freezed.dart
lib/src/l10n/characters_list_l10n.dart
lib/src/l10n/characters_list_l10n_de.dart
lib/src/l10n/characters_list_l10n_en.dart
lib/src/presentation/bloc/character_preview_bloc.injectable.json
lib/src/presentation/bloc/characters_list_bloc.freezed.dart
lib/src/presentation/bloc/characters_list_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/characters_list_paging_test.dart
test/feature/characters_list_test.dart
```

**PASS T-0032-AC6-not-committed**
