# T-0032-AC6: a bloc body edit cuts off before retrofit and the injectable aggregate

Edit: `assert('cutoff-1795581213-43562'.isNotEmpty);` added to the body of `close()` in `feature/characters/characters_list/lib/src/presentation/bloc/characters_list_bloc.dart`, then `build //feature/characters/characters_list:characters_list` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `192685730c453c3f` | `192685730c453c3f` |
| characters_list_api.g.dart sha256 | `36401c9e5f6ced2a` | `36401c9e5f6ced2a` |

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
DartCodegen	//feature/characters/characters_list:_di_config_src_domain_api_characters_list_api_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/characters/characters_list:_character_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/characters/characters_list:_di_config_src_domain_repository_characters_list_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/characters/characters_list:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/characters/characters_list:_di_config_src_presentation_bloc_character_preview_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/characters/characters_list:_list_bloc_freezed	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/characters/characters_list:characters_list	cacheHit=False	exitCode=0
DartCodegen	//feature/characters/characters_list:_di_config_src_presentation_bloc_characters_list_bloc_inj	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/characters/characters_list/lib/src/domain/api/characters_list_api.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/characters/characters_list/lib/src/domain/repository/characters_list_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/characters/characters_list/lib/src/presentation/bloc/character_preview_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/characters/characters_list/lib/src/presentation/bloc/characters_list_bloc.injectable.json
feature/characters/characters_list/lib/src/di/di_initializer.dart
```

**PASS T-0032-AC6-cutoff**
