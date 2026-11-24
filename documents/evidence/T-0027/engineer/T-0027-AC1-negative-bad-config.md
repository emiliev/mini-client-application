# T-0027-AC1: retrofit shim vs build_runner

```
== 1. Bazel codegen for //spike/api_envelope
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/api_envelope
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 15s; wrote 4 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin
EQUAL   spike/api_envelope/lib/src/api_page.g.dart
EQUAL   spike/api_envelope/lib/src/api_response.g.dart
== 1. Bazel codegen for //spike/retrofit_api
ERROR: /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-aba1a08860ba92b05/spike/retrofit_api/BUILD.bazel:69:13: DartCodegen @@//spike/retrofit_api:_characters_api_retrofit_part failed: (Exit 2): dart failed: error executing DartCodegen command (from dart_codegen rule target //spike/retrofit_api:_characters_api_retrofit_part) external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk/bin/dart bazel-out/darwin_arm64-opt-exec/bin/external/ai_rules_dart+/dart/ext/retrofit/shim.dill ... (remaining 1 argument skipped)
ERROR: Build did NOT complete successfully
BAZEL BUILD FAILED (exit 1): not comparing stale outputs
```

| Check | Result |
|---|---|
| spike_reference.sh | spike/api_envelope exit 0 spike/retrofit_api exit 1 |
| expected files EQUAL | 2 of 5 (must be exactly the list in this script) |
| `characters_api.g.dart` sha256 | `36eebd91a5ab2f756b46e271c0d1dbe5f8f21cda31492298eb180e1f6c55d0ea` |
| lines naming `_CharactersApi` in it | 2 |
| retrofit action runs `@rules_dart//dart/ext/retrofit:shim` | yes |
| retrofit action: `--summary` args / envelope summary among them / `sky_engine` mentions | 15 / 2 / 0 |

**FAIL T-0027-AC1**
