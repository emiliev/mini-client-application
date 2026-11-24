# T-0028-AC2: injectable early cutoff (H-DI-CUTOFF)

Edit: method body of `spike/di_sample/lib/src/greeting_repository.dart` (`greeting()` string; token `cutoff-1795560235-81890`), then `build //spike/di_sample:di_config` with `--execution_log_json_file`.

| | before | after |
|---|---|---|
| greeting_repository.injectable.json sha256 | `0326782b52c11c48` | `0326782b52c11c48` |
| di_initializer.config.dart sha256 | `d373324740114210` | `d373324740114210` |

Spawns in the execution log after the edit:

```
DartCodegen	//spike/di_sample:_di_config_src_badge_inj	cacheHit=False	exitCode=0
DartCodegen	//spike/di_sample:_di_config_src_clock_inj	cacheHit=False	exitCode=0
DartCodegen	//spike/di_sample:_di_config_src_greeter_inj	cacheHit=False	exitCode=0
DartCodegen	//spike/di_sample:_di_config_src_greeting_repository_inj	cacheHit=False	exitCode=0
DartCodegen	//spike/di_sample:_di_config_src_plain_helper_inj	cacheHit=False	exitCode=0
DartCodegen	//spike/di_sample:_di_config_src_sample_module_inj	cacheHit=False	exitCode=0
```

- edited file's shard executed (cacheHit=False): DartCodegen	//spike/di_sample:_di_config_src_greeting_repository_inj	cacheHit=False	exitCode=0
- aggregate spawns that were not cache hits: none
- aggregate action spawns: none (action-cache hit)

Package-local inputs of the aggregate action (aquery):

```
bazel-out/darwin_arm64-fastbuild/bin/spike/di_sample/lib/src/badge.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/spike/di_sample/lib/src/clock.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/spike/di_sample/lib/src/greeter.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/spike/di_sample/lib/src/greeting_repository.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/spike/di_sample/lib/src/plain_helper.injectable.json
bazel-out/darwin_arm64-fastbuild/bin/spike/di_sample/lib/src/sample_module.injectable.json
spike/di_sample/lib/src/di/di_initializer.dart
```

**PASS T-0028-AC2**
