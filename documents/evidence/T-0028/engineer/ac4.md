# T-0028-AC4: empty shard, and an init that generates nothing

| Case | Result |
|---|---|
| `plain_helper.dart` ("@injectable" only in a comment): shard | `[]` |
| `:di_config` with that shard | exit 0, .config.dart 2027 bytes |
| `:di_config_without_init` (no @InjectableInit) | exit 1, output not written; `injectable config: testdata/di_without_init.dart generated nothing for testdata/di_without_init.config.dart.` |
| `:di_config_unresolved_init` (package:injectable not in deps) | exit 1, output not written; `Could not resolve annotation for `Future<void> _init(GetIt getIt, String? environment)`.` |

Unit tests: `@rules_dart//dart/ext/injectable:injectable_shims_test` (T-0028-AC4 cases) and `//spike/di_sample:di_sample_test`.

**PASS T-0028-AC4**
