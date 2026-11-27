# T-0064-AC7: a bloc body edit cuts off before retrofit and the injectable aggregate

Edit: `assert('cutoff-1795799841-73445'.isNotEmpty);` added to the round start of `TriviaPlayBloc._load` in `feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_play_bloc.dart`, then `build //feature/trivia/trivia_quiz:trivia_quiz` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `d0b93a5c7a5e711c` | `d0b93a5c7a5e711c` |
| trivia_quiz_api.g.dart sha256 | `18a50d54540db454` | `18a50d54540db454` |

| Check | Result |
|---|---|
| positive control: bloc freezed action executed | yes |
| positive control: bloc injectable shard executed | yes |
| aggregate spawns that were not cache hits | none |
| retrofit part / API combine / DTO json spawns that ran | none |
| bloc files among the retrofit action's inputs | 0 |
| bloc file among the aggregate action's inputs | 0 |

Spawns in the execution log after the edit:

```
DartCodegen	//feature/trivia/trivia_quiz:_di_config_src_domain_api_trivia_quiz_api_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_trivia_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_di_config_src_domain_repository_trivia_quiz_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_play_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_di_config_src_presentation_bloc_trivia_play_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_results_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_di_config_src_presentation_bloc_trivia_results_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_setup_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/trivia/trivia_quiz:_di_config_src_presentation_bloc_trivia_setup_bloc_inj	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/trivia/trivia_quiz:trivia_quiz	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/trivia/trivia_quiz/lib/src/domain/api/trivia_quiz_api.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/trivia/trivia_quiz/lib/src/domain/repository/trivia_quiz_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_play_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_results_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/trivia/trivia_quiz/lib/src/presentation/bloc/trivia_setup_bloc.injectable.json
feature/trivia/trivia_quiz/lib/src/di/di_initializer.dart
```

**PASS T-0064-AC7-cutoff**
