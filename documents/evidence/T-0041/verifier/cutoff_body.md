# T-0041-AC7: a bloc body edit cuts off before retrofit and the injectable aggregate

Edit: `assert('cutoff-1795719943-86658'.isNotEmpty);` added to the body of `_toggle` in `feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.dart`, then `build //feature/comics/comics_details:comics_details` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `0bf8dd209ab5fafa` | `0bf8dd209ab5fafa` |
| comics_details_api.g.dart sha256 | `2c6e502fd1e911a2` | `2c6e502fd1e911a2` |

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
DartCodegen	//feature/comics/comics_details:_di_config_src_domain_api_comics_details_api_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_comic_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_di_config_src_domain_repository_comics_details_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_details_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_di_config_src_presentation_bloc_comic_details_bloc_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_favourite_bloc_freezed	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/comics/comics_details:comics_details	cacheHit=False	exitCode=0
DartCodegen	//feature/comics/comics_details:_di_config_src_presentation_bloc_comic_favourite_bloc_inj	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/comics/comics_details/lib/src/domain/api/comics_details_api.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/comics/comics_details/lib/src/domain/repository/comics_details_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/comics/comics_details/lib/src/presentation/bloc/comic_details_bloc.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.injectable.json
feature/comics/comics_details/lib/src/di/di_initializer.dart
```

**PASS T-0041-AC7-cutoff**
