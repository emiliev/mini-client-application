# T-0063-AC7: generated files are Bazel outputs, never committed

Generated files in the git index under `feature/settings/settings_appearance`: none

| Kind | File (package-relative) | declared Bazel output | git-ignored |
|---|---|---|---|
| freezed (flow state) | `lib/src/flow/settings_appearance_flow_state.freezed.dart` | yes | yes |
| freezed (bloc state) | `lib/src/presentation/bloc/appearance_bloc.freezed.dart` | yes | yes |
| injectable config | `lib/src/di/di_initializer.config.dart` | yes | yes |
| injectable shard | `lib/src/presentation/bloc/appearance_bloc.injectable.json` | yes | yes |
| gen-l10n | `lib/src/l10n/settings_appearance_l10n.dart` | yes | yes |
| gen-l10n (de) | `lib/src/l10n/settings_appearance_l10n_de.dart` | yes | yes |
| gen-l10n (en) | `lib/src/l10n/settings_appearance_l10n_en.dart` | yes | yes |
| BDD test | `test/feature/settings_appearance_test.dart` | yes | n/a (bazel-out only) |
| BDD test | `test/feature/settings_appearance_sync_test.dart` | yes | n/a (bazel-out only) |
| BDD main | `test/feature/bdd_test_main.dart` | yes | n/a (bazel-out only) |

Hand-written paths the scoped ignore rules must leave visible:

| File | git |
|---|---|
| `test/feature/helpers_test.dart` | visible |
| `lib/src/app.config.dart` | visible |
| `test/feature/step/i_open_the_appearance_settings.dart` | visible |

All declared outputs of the package's generator targets (10):

```
lib/src/di/di_initializer.config.dart
lib/src/flow/settings_appearance_flow_state.freezed.dart
lib/src/l10n/settings_appearance_l10n.dart
lib/src/l10n/settings_appearance_l10n_de.dart
lib/src/l10n/settings_appearance_l10n_en.dart
lib/src/presentation/bloc/appearance_bloc.freezed.dart
lib/src/presentation/bloc/appearance_bloc.injectable.json
test/feature/bdd_test_main.dart
test/feature/settings_appearance_sync_test.dart
test/feature/settings_appearance_test.dart
```

**PASS T-0063-AC7-not-committed**
