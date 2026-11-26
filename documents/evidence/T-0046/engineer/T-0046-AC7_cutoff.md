# T-0046-AC7: a bloc body edit cuts off before retrofit and the injectable aggregate

Edit: `assert('cutoff-1795728697-29954'.isNotEmpty);` added to the body of `_search` in `feature/discovery/discovery_search/lib/src/presentation/bloc/discovery_search_bloc.dart`, then `build //feature/discovery/discovery_search:discovery_search` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `3409b2475d4f96a0` | `3409b2475d4f96a0` |
| discovery_search_api.g.dart sha256 | `8a0084d41c6df004` | `8a0084d41c6df004` |

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
DartCodegen	//feature/discovery/discovery_search:_di_config_src_di_di_module_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/discovery/discovery_search:_di_config_src_domain_api_discovery_search_api_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/discovery/discovery_search:_search_results_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/discovery/discovery_search:_di_config_src_domain_repository_discovery_search_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//feature/discovery/discovery_search:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/discovery/discovery_search:_search_bloc_freezed	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/discovery/discovery_search:discovery_search	cacheHit=False	exitCode=0
DartCodegen	//feature/discovery/discovery_search:_di_config_src_presentation_bloc_discovery_search_bloc_inj	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/discovery/discovery_search/lib/src/di/di_module.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/discovery/discovery_search/lib/src/domain/api/discovery_search_api.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/discovery/discovery_search/lib/src/domain/repository/discovery_search_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/feature/discovery/discovery_search/lib/src/presentation/bloc/discovery_search_bloc.injectable.json
feature/discovery/discovery_search/lib/src/di/di_initializer.dart
```

**PASS T-0046-AC7-cutoff**
