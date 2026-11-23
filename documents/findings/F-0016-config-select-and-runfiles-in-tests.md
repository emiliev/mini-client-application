# F-0016: selecting a build-setting value in a `dart_test` (T-0020)

1. `dart_test.env` is a `string_dict`; a `select()` cannot sit on a dict *value*. Select the **whole dict** (`env = select({cond: {...}})`). `$(rootpath <label>)` expands there when the label is in `data`.
2. A genrule with `srcs = select({...})` named `app_config` gives the bundled `app_config.json` for any consumer. With `--//tool/bazel/config:env=e2e` the `mc_config:bundled_config_test` passes with `latency == 0`, and `aquery` over its deps shows 0 `--dart-define` occurrences (AC1).
3. Tests that must read package sources (the no-Flutter check) get `data = glob(["lib/**/*.dart"])`. Under Bazel the cwd is the runfiles root, so the test tries `utility/<pkg>/lib` and falls back to `lib` for plain `dart test`.
4. `mc_config` stays Flutter-free: `ConfigDIInitializer` takes a `ConfigSource` (`Future<String> Function()`); `app_core` supplies the `rootBundle` loader.
