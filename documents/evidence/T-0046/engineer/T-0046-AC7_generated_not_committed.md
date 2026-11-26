# T-0046-AC7: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/discovery/discovery_search`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| retrofit client | `lib/src/domain/api/discovery_search_api.g.dart` | yes | yes |
| json part | `lib/src/domain/model/search_dto.g.dart` | yes | yes |
| freezed (DTO) | `lib/src/domain/model/search_dto.freezed.dart` | yes | yes |
| freezed (domain) | `lib/src/domain/model/search_results.freezed.dart` | yes | yes |
| freezed (flow state) | `lib/src/flow/discovery_search_flow_state.freezed.dart` | yes | yes |
| freezed (bloc state) | `lib/src/presentation/bloc/discovery_search_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard (module) | `lib/src/di/di_module.injectable.json` | yes | yes |
| injectable shard (bloc) | `lib/src/presentation/bloc/discovery_search_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/discovery_search_l10n.dart` | yes | yes |
| gen-l10n (de) | `lib/src/l10n/discovery_search_l10n_de.dart` | yes | yes |
| BDD test | `test/feature/discovery_search_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/discovery_search_typing_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/discovery_search_fixture_sets_test.dart` | yes | n/a (bazel-out only) |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

Hand-written paths the scoped ignore rules must leave visible:

| File | git |
|---|---|
| `test/feature/helpers_test.dart` | visible |
| `lib/src/app.config.dart` | visible |
| `test/feature/step/i_open_the_search.dart` | visible |

All declared outputs of the package's generator targets (20):

```
lib/src/di/di_initializer.config.dart
lib/src/di/di_module.injectable.json
lib/src/domain/api/discovery_search_api.g.dart
lib/src/domain/api/discovery_search_api.injectable.json
lib/src/domain/api/discovery_search_api.retrofit.g.part
lib/src/domain/model/search_dto.freezed.dart
lib/src/domain/model/search_dto.g.dart
lib/src/domain/model/search_dto.json_serializable.g.part
lib/src/domain/model/search_results.freezed.dart
lib/src/domain/repository/discovery_search_repository.injectable.json
lib/src/flow/discovery_search_flow_state.freezed.dart
lib/src/l10n/discovery_search_l10n.dart
lib/src/l10n/discovery_search_l10n_de.dart
lib/src/l10n/discovery_search_l10n_en.dart
lib/src/presentation/bloc/discovery_search_bloc.freezed.dart
lib/src/presentation/bloc/discovery_search_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/discovery_search_fixture_sets_test.dart
test/feature/discovery_search_test.dart
test/feature/discovery_search_typing_test.dart
```

**PASS T-0046-AC7-not-committed**
