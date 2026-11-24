# Verifier negatives at 5f5c71e

Output base `/tmp/mc-ob-T-0027-verifier`. Every edit was reverted with `git checkout --` (`git status` clean).

## N1. Execution-time codegen failure (`config = "{not json",` on `_characters_api_retrofit_part`)
```
$ tool/build_runner_overlay/spike_reference.sh spike/retrofit_api; echo rc=$?
ERROR: <worktree>/spike/retrofit_api/BUILD.bazel:69:13: DartCodegen @@//spike/retrofit_api:_characters_api_retrofit_part failed …
ERROR: Build did NOT complete successfully
BAZEL BUILD FAILED (exit 1): not comparing stale outputs
rc=1

$ tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh; echo rc=$?
EQUAL   spike/api_envelope/lib/src/api_page.g.dart
EQUAL   spike/api_envelope/lib/src/api_response.g.dart
BAZEL BUILD FAILED (exit 1): not comparing stale outputs
| spike_reference.sh | spike/api_envelope exit 0 spike/retrofit_api exit 1 |
| expected files EQUAL | 2 of 5 (must be exactly the list in this script) |
**FAIL T-0027-AC1**
rc=1
```

## N2. A generated file really missing from bazel-bin
The `_character_dto_g` combine was changed to `output_suffixes = [".gen.dart"]`.

**N2a, warm output base:** Bazel leaves the previously built `character_dto.g.dart` in `bazel-bin` as an orphan. It is no longer a declared output, but it is still compared, so the check reports PASS:
```
EQUAL   spike/retrofit_api/lib/src/character_dto.g.dart
| expected files EQUAL | 5 of 5 … |
**PASS T-0027-AC1**          (bazel-bin holds both character_dto.g.dart (stale) and character_dto.gen.dart)
```

**N2b, orphan deleted** (the file is really absent, as in a clean output base):
```
MISSING in bazel-bin: spike/retrofit_api/lib/src/character_dto.g.dart
| spike_reference.sh | spike/api_envelope exit 0 spike/retrofit_api exit 1 |
| expected files EQUAL | 4 of 5 … |
**FAIL T-0027-AC1**
rc=1
```

## N3. AC4: the README `Changelog:` differs from the patch trailer
The README line was changed to "… for `@RestApi` clients" (the word "dio" removed).
```
| `Changelog:` trailer (69 chars, max 100) equals README's | no: patch `Changelog: `retrofit_library` runs retrofit_generator for `@RestApi` dio clients`, README `Changelog: `retrofit_library` runs retrofit_generator for `@RestApi` clients` |
**FAIL T-0027-AC4**
rc=1
```
