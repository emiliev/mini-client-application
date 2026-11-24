# Verifier: the reference script and the AC1 check against a failing Bazel build

Output base `/tmp/mc-ob-T-0027-verifier`. Every edit was reverted afterwards (`git status` clean).

## A. Analysis failure: `spike_reference.sh` exits 0
Setup: the API was mutated (a path change plus a new endpoint) and built once. Then `generator_bin` of `_characters_api_retrofit_part` was set to `@rules_dart//dart/ext/retrofit:no_such_shim`.

```
$ tool/build_runner_overlay/spike_reference.sh spike/retrofit_api; echo rc=$?
ERROR: …/external/ai_rules_dart+/dart/ext/retrofit/BUILD.bazel: no such target '@@ai_rules_dart+//dart/ext/retrofit:no_such_shim' …
ERROR: …/spike/retrofit_api/BUILD.bazel:69:13: no such target '@@ai_rules_dart+//dart/ext/retrofit:no_such_shim' …
ERROR: Analysis of target '//spike/retrofit_api:_characters_api_retrofit_part' failed; build aborted: Analysis failed
ERROR: Build did NOT complete successfully
EQUAL   spike/retrofit_api/lib/src/character_dto.freezed.dart
EQUAL   spike/retrofit_api/lib/src/character_dto.g.dart
EQUAL   spike/retrofit_api/lib/src/characters_api.g.dart
rc=0
```
The `EQUAL` lines compare build_runner's output with **stale** `bazel-bin` files from the previous build. In this case the AC1 check would still fail, because its `aquery` fails at analysis too. Case B is the one it misses.

## B. Execution failure: the AC1 check reports PASS
Setup: clean source. `config = "{not json"` was added to `_characters_api_retrofit_part`, which analyses fine and fails when the action runs.

```
$ tool/bazelw … build //spike/retrofit_api:_characters_api_g
ERROR: …/spike/retrofit_api/BUILD.bazel:69:13: DartCodegen @@//spike/retrofit_api:_characters_api_retrofit_part failed: (Exit 2): dart …
ERROR: Build did NOT complete successfully

$ tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh; echo rc=$?
EQUAL   spike/api_envelope/lib/src/api_page.g.dart
EQUAL   spike/api_envelope/lib/src/api_response.g.dart
EQUAL   spike/retrofit_api/lib/src/character_dto.freezed.dart
EQUAL   spike/retrofit_api/lib/src/character_dto.g.dart
EQUAL   spike/retrofit_api/lib/src/characters_api.g.dart
| retrofit action runs `@rules_dart//dart/ext/retrofit:shim` | yes |
**PASS T-0027-AC1**
rc=0
```
The check's line filter (`^(==|   |EQUAL|…)`) also drops the `ERROR` lines, so the report doesn't show that the build failed.

Root cause: `tool/build_runner_overlay/spike_reference.sh:34` ends the Bazel build pipeline with `|| true`. This is P-024, scheduled "before P3-03 shims", and still open. `tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh:15-38` never checks the build's exit status on its own.
