# T-0048-AC7: a bloc body edit cuts off before retrofit and the injectable aggregate

Edit: `assert('cutoff-1795735047-18799'.isNotEmpty);` added to the body of `_save` in `feature/library/library_reading_list_editor/lib/src/presentation/bloc/reading_list_editor_bloc.dart`, then `build //feature/library/library_reading_list_editor:library_reading_list_editor` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `f09bd3e34954fe59` | `f09bd3e34954fe59` |
| reading_list_editor_api.g.dart sha256 | `68fafa773c30936f` | `68fafa773c30936f` |

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
DartCodegen	//feature/library/library_reading_list_editor:_di_config_src_domain_api_reading_list_editor_api_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_reading_list_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_di_config_src_domain_repository_reading_list_editor_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_picker_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_di_config_src_presentation_bloc_comic_picker_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_editor_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/library/library_reading_list_editor:_di_config_src_presentation_bloc_reading_list_editor_bloc_inj	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/library/library_reading_list_editor:library_reading_list_editor	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/library/library_reading_list_editor/lib/src/domain/api/reading_list_editor_api.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/library/library_reading_list_editor/lib/src/domain/repository/reading_list_editor_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/library/library_reading_list_editor/lib/src/presentation/bloc/comic_picker_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/library/library_reading_list_editor/lib/src/presentation/bloc/reading_list_editor_bloc.injectable.json
feature/library/library_reading_list_editor/lib/src/di/di_initializer.dart
```

**PASS T-0048-AC7-cutoff**
