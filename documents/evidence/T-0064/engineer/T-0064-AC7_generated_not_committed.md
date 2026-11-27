# T-0064-AC7: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/trivia/trivia_quiz`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| retrofit client | `lib/src/domain/api/trivia_quiz_api.g.dart` | yes | yes |
| json part | `lib/src/domain/model/trivia_dto.g.dart` | yes | yes |
| freezed (DTO) | `lib/src/domain/model/trivia_dto.freezed.dart` | yes | yes |
| freezed (domain) | `lib/src/domain/model/trivia.freezed.dart` | yes | yes |
| freezed (flow state) | `lib/src/flow/trivia_quiz_flow_state.freezed.dart` | yes | yes |
| freezed (setup bloc state) | `lib/src/presentation/bloc/trivia_setup_bloc.freezed.dart` | yes | yes |
| freezed (play bloc state) | `lib/src/presentation/bloc/trivia_play_bloc.freezed.dart` | yes | yes |
| freezed (results bloc state) | `lib/src/presentation/bloc/trivia_results_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard | `lib/src/presentation/bloc/trivia_play_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/trivia_quiz_l10n.dart` | yes | yes |
| gen-l10n (de) | `lib/src/l10n/trivia_quiz_l10n_de.dart` | yes | yes |
| BDD test | `test/feature/trivia_quiz_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/trivia_quiz_scoring_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/trivia_quiz_timer_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/trivia_quiz_l10n_test.dart` | yes | n/a (bazel-out only) |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

Hand-written paths the scoped ignore rules must leave visible:

| File | git |
|---|---|
| `test/feature/helpers_test.dart` | visible |
| `lib/src/app.config.dart` | visible |
| `test/feature/step/i_open_the_trivia.dart` | visible |

All declared outputs of the package's generator targets (24):

```
lib/src/di/di_initializer.config.dart
lib/src/domain/api/trivia_quiz_api.g.dart
lib/src/domain/api/trivia_quiz_api.injectable.json
lib/src/domain/api/trivia_quiz_api.retrofit.g.part
lib/src/domain/model/trivia.freezed.dart
lib/src/domain/model/trivia_dto.freezed.dart
lib/src/domain/model/trivia_dto.g.dart
lib/src/domain/model/trivia_dto.json_serializable.g.part
lib/src/domain/repository/trivia_quiz_repository.injectable.json
lib/src/flow/trivia_quiz_flow_state.freezed.dart
lib/src/l10n/trivia_quiz_l10n.dart
lib/src/l10n/trivia_quiz_l10n_de.dart
lib/src/l10n/trivia_quiz_l10n_en.dart
lib/src/presentation/bloc/trivia_play_bloc.freezed.dart
lib/src/presentation/bloc/trivia_play_bloc.injectable.json
lib/src/presentation/bloc/trivia_results_bloc.freezed.dart
lib/src/presentation/bloc/trivia_results_bloc.injectable.json
lib/src/presentation/bloc/trivia_setup_bloc.freezed.dart
lib/src/presentation/bloc/trivia_setup_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/trivia_quiz_l10n_test.dart
test/feature/trivia_quiz_scoring_test.dart
test/feature/trivia_quiz_test.dart
test/feature/trivia_quiz_timer_test.dart
```

**PASS T-0064-AC7-not-committed**
