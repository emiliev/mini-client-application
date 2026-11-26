# T-0042-AC5: gates on the synced tree ( synced files)

| Gate | Result |
|---|---|
| tool/ide_sync --env dev (the gates run on the synced tree) | **FAIL** |
| test //... (synced tree) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| ide_sync script tests (T-0042-AC5) | PASS |
| T-0032-AC6 byte-identity with build_runner (synced tree) | PASS |

- tests: Executed 0 out of 101 tests: 101 tests pass.

### tool/ide_sync --env dev (the gates run on the synced tree) failed

```
ide_sync: query: codegen targets under the workspace
ide_sync: build: 42 codegen targets
ide_sync: Bazel did not produce spike/api_envelope/lib/src/api_page.g.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/spike/api_envelope/lib/src/api_page.g.dart)
ide_sync: Bazel did not produce spike/api_envelope/lib/src/api_response.g.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/spike/api_envelope/lib/src/api_response.g.dart)
ide_sync: Bazel did not produce spike/di_sample/lib/src/di/di_initializer.config.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/spike/di_sample/lib/src/di/di_initializer.config.dart)
ide_sync: Bazel did not produce spike/retrofit_api/lib/src/character_dto.freezed.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/spike/retrofit_api/lib/src/character_dto.freezed.dart)
ide_sync: Bazel did not produce spike/retrofit_api/lib/src/character_dto.g.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/spike/retrofit_api/lib/src/character_dto.g.dart)
ide_sync: Bazel did not produce spike/retrofit_api/lib/src/characters_api.g.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/spike/retrofit_api/lib/src/characters_api.g.dart)
ide_sync: Bazel did not produce utility/mc_api_client/lib/src/api_page.g.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/utility/mc_api_client/lib/src/api_page.g.dart)
ide_sync: Bazel did not produce utility/mc_paging/lib/src/paged_state.freezed.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/utility/mc_paging/lib/src/paged_state.freezed.dart)
ide_sync: Bazel did not produce utility/mc_paging/test/support/holder_state.freezed.dart (bazel-out/darwin_arm64-fastbuild-ST-bdcb722b2755/bin/utility/mc_paging/test/support/holder_state.freezed.dart)
ide_sync: could not list the Bazel outputs
```

**FAIL T-0042-AC5-gates**
