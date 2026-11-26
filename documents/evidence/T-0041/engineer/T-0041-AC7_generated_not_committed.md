# T-0041-AC7: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/comics/comics_details`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| retrofit client | `lib/src/domain/api/comics_details_api.g.dart` | yes | yes |
| json part | `lib/src/domain/model/comic_dto.g.dart` | yes | yes |
| freezed (DTO) | `lib/src/domain/model/comic_dto.freezed.dart` | yes | yes |
| freezed (domain) | `lib/src/domain/model/comic.freezed.dart` | yes | yes |
| freezed (flow state) | `lib/src/flow/comics_details_flow_state.freezed.dart` | yes | yes |
| freezed (details bloc state) | `lib/src/presentation/bloc/comic_details_bloc.freezed.dart` | yes | yes |
| freezed (favourite bloc state) | `lib/src/presentation/bloc/comic_favourite_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard | `lib/src/presentation/bloc/comic_favourite_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/comics_details_l10n.dart` | yes | yes |
| gen-l10n (de) | `lib/src/l10n/comics_details_l10n_de.dart` | yes | yes |
| BDD test | `test/feature/comics_details_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/comics_details_favourite_test.dart` | yes | n/a (bazel-out only) |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

Hand-written paths the scoped ignore rules must leave visible:

| File | git |
|---|---|
| `test/feature/helpers_test.dart` | visible |
| `lib/src/app.config.dart` | visible |
| `test/feature/step/i_open_comic.dart` | visible |

All declared outputs of the package's generator targets (20):

```
lib/src/di/di_initializer.config.dart
lib/src/domain/api/comics_details_api.g.dart
lib/src/domain/api/comics_details_api.injectable.json
lib/src/domain/api/comics_details_api.retrofit.g.part
lib/src/domain/model/comic.freezed.dart
lib/src/domain/model/comic_dto.freezed.dart
lib/src/domain/model/comic_dto.g.dart
lib/src/domain/model/comic_dto.json_serializable.g.part
lib/src/domain/repository/comics_details_repository.injectable.json
lib/src/flow/comics_details_flow_state.freezed.dart
lib/src/l10n/comics_details_l10n.dart
lib/src/l10n/comics_details_l10n_de.dart
lib/src/l10n/comics_details_l10n_en.dart
lib/src/presentation/bloc/comic_details_bloc.freezed.dart
lib/src/presentation/bloc/comic_details_bloc.injectable.json
lib/src/presentation/bloc/comic_favourite_bloc.freezed.dart
lib/src/presentation/bloc/comic_favourite_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/comics_details_favourite_test.dart
test/feature/comics_details_test.dart
```

**PASS T-0041-AC7-not-committed**
