# T-0027-AC1: retrofit shim vs build_runner

```
== 1. Bazel codegen for //spike/api_envelope
INFO: Build completed successfully, 11 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/api_envelope
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 4 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin
EQUAL   spike/api_envelope/lib/src/api_page.g.dart
EQUAL   spike/api_envelope/lib/src/api_response.g.dart
== 1. Bazel codegen for //spike/retrofit_api
INFO: Build completed successfully, 14 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/retrofit_api
   first-party path dep: api_envelope (spike/api_envelope)
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 5 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin
EQUAL   spike/retrofit_api/lib/src/character_dto.freezed.dart
EQUAL   spike/retrofit_api/lib/src/character_dto.g.dart
EQUAL   spike/retrofit_api/lib/src/characters_api.g.dart
```

| Check | Result |
|---|---|
| spike_reference.sh | spike/api_envelope exit 0 spike/retrofit_api exit 0 |
| expected files EQUAL | 5 of 5 (must be exactly the list in this script) |
| `characters_api.g.dart` sha256 | `36eebd91a5ab2f756b46e271c0d1dbe5f8f21cda31492298eb180e1f6c55d0ea` |
| lines naming `_CharactersApi` in it | 2 |
| retrofit action runs `@rules_dart//dart/ext/retrofit:shim` | yes |
| retrofit action: `--summary` args / envelope summary among them / `sky_engine` mentions | 15 / 2 / 0 |

**PASS T-0027-AC1**
