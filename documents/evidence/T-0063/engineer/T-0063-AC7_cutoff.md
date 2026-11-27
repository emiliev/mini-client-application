# T-0063-AC7: a bloc body edit cuts off before the injectable aggregate

Edit: `assert('cutoff-1795798021-58466'.isNotEmpty);` added to the `_OpenAbout` case of `AppearanceBloc._onEvent` in `feature/settings/settings_appearance/lib/src/presentation/bloc/appearance_bloc.dart`, then `build //feature/settings/settings_appearance:settings_appearance` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| di_initializer.config.dart sha256 | `6ced70dd680f0d8e` | `6ced70dd680f0d8e` |

| Check | Result |
|---|---|
| positive control: bloc freezed action executed | yes |
| positive control: bloc injectable shard executed | yes |
| aggregate spawns that were not cache hits | none |
| bloc file among the aggregate action's inputs | 0 |

Spawns in the execution log after the edit:

```
DartCodegen	//feature/settings/settings_appearance:_flow_state_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/settings/settings_appearance:_appearance_bloc_freezed	cacheHit=False	exitCode=0
DartCodegen	//feature/settings/settings_appearance:_di_config_src_presentation_bloc_appearance_bloc_inj	cacheHit=False	exitCode=0
DartAnalyzerSummary	//feature/settings/settings_appearance:settings_appearance	cacheHit=False	exitCode=0
```

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/feature/settings/settings_appearance/lib/src/presentation/bloc/appearance_bloc.injectable.json
feature/settings/settings_appearance/lib/src/di/di_initializer.dart
```

**PASS T-0063-AC7-cutoff**
