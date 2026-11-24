# Verification report — T-0027: retrofit codegen shim on the rules_dart fork

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0027-retrofit-shim` @ `eee1877`. Checked out detached, because the Engineer's worktree holds the branch.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0027-verifier` for all builds. The check scripts were routed there through `MC_BAZELISK=<wrapper adding --output_base>`. The repro ran on `/tmp/mc-ob-T-0027-verifier-repro`, and the fork lock probe on `/tmp/mc-ob-T-0027-verifier-fork`. All three servers were shut down at the end.
- **Fork:** own dir, `MC_FORK_DIR=<scratch>/forks`, through `tool/rules_fork.sh checkout ai_rules_dart`. The generated `.bazelrc.user` was deleted before any gate in the worktree ran.
- **Simulator:** none. This is a pure-Dart build-tooling task with no UI and no e2e journey.
- **Verdict:** **FAIL.** All of the product behaviour is confirmed: byte identity, the mutation, rerun scope, the gates and the repro. But the check mapped to AC1 reports PASS on a failed Bazel build (defect 1, major). This is the P-024 bug class the brief asked about, and P-024 was scheduled "before P3-03 shims", which is this task. The fix is small and fits the one fix round: honour the build's exit status in `spike_reference.sh` and/or the AC1 check. After that, a quick re-verify of AC1 is enough.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| L0 Format | `fvm dart format --output=none --set-exit-if-changed spike/api_envelope spike/retrofit_api` | 7 files, 0 changed |
| Lint (analyze + format aspects) | `tool/bazelw … build --config=lint //...` | exit 0 |
| Tests | `tool/bazelw … test --lockfile_mode=error --nocache_test_results //...` | **48/48 pass**, all executed, none cached. `characters_api_test`: 3/3 `T-0027-AC1 …` cases |
| Layers | `tool/bazelw … run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Patch queue | `tool/rules_fork.sh check` / `status` | `1 patch(es) apply strictly on pin e7163aab8f91`; `patches match the queue`; `override: none` |
| Fork tooling | `tool/test/rules_fork_test.sh` | 21 passed, 0 failed |
| Coverage / L4 e2e | n/a | Tooling spike: no domain/data code and no feature journey |

`tool/verify.sh` doesn't exist yet (T-0005), so these are the equivalent gates.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0027-AC1 | Bazel `.g.dart` of an `@RestApi` file over a freezed+json model and `ApiResponse<T>` equals build_runner's byte for byte | `tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh`; `//spike/retrofit_api:characters_api_test` | **Partly.** The comparison and the client test are real. But the check passes when the Bazel build fails: stale `bazel-bin` is compared (defect 1) | **FAIL** (behaviour confirmed; the check is unsound) |
| T-0027-AC2 | Body edit in the API file reruns only that file's retrofit, combine and kernel actions | `tool/checks/T-0027-AC2_retrofit_rerun_scope.sh` | yes (exact `DartCodegen` set, shard hash identical, 0 envelope or DTO codegen spawns, same flags on both builds) | PASS |
| T-0027-AC3 | Ext lock on analyzer 14.5.0; `check`/`status`; `test //...`, lint, `mc_arch_check` green | `tool/checks/T-0027-AC3_patch_queue_and_ext_lock.sh` | yes (reads the lock Bazel actually patched into `external/ai_rules_dart+`; no override active) | PASS |
| T-0027-AC4 | Upstream draft with a minimal repro workspace | `tool/checks/T-0027-AC4_upstream_draft.sh` with `MC_RULES_FORK` | yes; `repro.sh` fails on a failed `bazel test` (`status=1`) and on a `DIFFER` | PASS |

### AC1: byte identity (re-derived)
Command: `tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh`, which runs the overlay build_runner in `.dart_tool/mc_overlay/`. Full output: [verifier/T-0027-AC1.md](verifier/T-0027-AC1.md). I hashed both sides myself as well:

| File | build_runner sha256[:16] | Bazel sha256[:16] |
|---|---|---|
| `spike/api_envelope/lib/src/api_page.g.dart` (other package) | `55391eed10cf0494` | `55391eed10cf0494` |
| `spike/api_envelope/lib/src/api_response.g.dart` (other package) | `e45a8e5bd25d792f` | `e45a8e5bd25d792f` |
| `spike/retrofit_api/lib/src/character_dto.freezed.dart` | `9c694ecd50cbe31a` | `9c694ecd50cbe31a` |
| `spike/retrofit_api/lib/src/character_dto.g.dart` | `abf784ac3e0fd524` | `abf784ac3e0fd524` |
| `spike/retrofit_api/lib/src/characters_api.g.dart` | `36eebd91a5ab2f75` | `36eebd91a5ab2f75` (= Engineer's) |

- **Envelope through summaries:** the retrofit action's `aquery` has 15 `--summary` args. `spike/api_envelope/api_envelope.dart_analyzer_summary.sum` is among them, and `sky_engine` doesn't appear. The envelope's sources are also staged in the action's `pkg_roots` (rules_dart behaviour), so an envelope edit will invalidate the retrofit action. That's outside AC2's scope.
- **Mutation:** I changed `@GET('v1/characters/{id}')` to `v2/heroes/{id}` and added `@DELETE … unfavourite(@Path('id') int id, @Query('reason') String? reason)`. Both sides changed to sha256 `1ab9361575bbaf51…` and stayed `EQUAL`. The generated file contains `'v2/heroes/${id}'` and `unfavourite(int id, String? reason)`. Reverted afterwards.
- **Client really works:** `characters_api_test` builds a real `Dio` with a canned `HttpClientAdapter`, so requests go through the generated `_CharactersApi`, Dio's request pipeline and JSON transformer. It asserts the decoded nested `ApiResponse<ApiPage<CharacterDto>>`, the query and path params, and a freezed `@Body` serialized to JSON. It is not a stub. It doesn't use `mc_mocked_backend`, which the brief allowed ("or a Dio adapter").
- **F-0025 claim reproduced:** with a bare `@freezed`, `character_dto.freezed.dart` and `.g.dart` come out `DIFFER`: Bazel has 0 `toJson` and a 3-line `.g.dart`, while build_runner has the JSON members. `characters_api.g.dart` stays `EQUAL`. But see defect 2 for the Engineer's log file.
- **Build-failure masking (defect 1):** [verifier/build-failure-masking.md](verifier/build-failure-masking.md).

### AC2: incremental (re-derived)
- API body edit (`tool/checks/T-0027-AC2_retrofit_rerun_scope.sh`, [verifier/T-0027-AC2.md](verifier/T-0027-AC2.md)): 11 spawns, all `ran` (cacheHit false), all in `//spike/retrofit_api`. The `DartCodegen` ones are exactly `_characters_api_retrofit_part` ×2 and `_characters_api_g` ×2, twice because of the test configuration (X9). The shard (`4fde39721cab2316`) and the `.g.dart` (`36eebd91…`) are unchanged. There were 0 envelope spawns and 0 `character_dto` codegen spawns. This matches the Engineer's figures exactly.
- **Flags:** both measured builds use the same `FLAGS=(--remote_download_all --disk_cache=)`. Only the `--execution_log_json_file` path differs, and that isn't part of any action key. No `--disk_cache` change happens between them (F-0026 §6 respected).
- Model edit (my own script, [verifier/model-edit-rerun.md](verifier/model-edit-rerun.md)): adding a field to `CharacterDto` reran 19 spawns. These were the model's freezed, json and combine actions, its dependent retrofit shard (through `_stage_frz`), the summaries, the kernels and the test. The API combine was cut off because the shard was byte-identical. The envelope ran nothing. So dependents do rerun.

### AC3: gates and ext lock
- See [verifier/T-0027-AC3.md](verifier/T-0027-AC3.md) and the gates table above.
- The patched ext lock reads analyzer / build / source_gen **14.5.0 / 4.0.11 / 4.3.1**, and retrofit_generator / retrofit / dio 10.3.3 / 4.10.0 / 5.11.1.
- The ext lock hunks in patch 0001 **add exactly** dio 5.11.1, dio_web_adapter 2.2.2, retrofit 4.10.0 and retrofit_generator 10.3.3. They remove or modify no other entry, which matches the Engineer's list.
- The root `MODULE.bazel.lock` churn (+1386/−151) is the `ext_pub_deps` / `pub_deps` hub regenerating: new dio/retrofit repos, an SCC target, `scc_targets` fields and input hashes. `--lockfile_mode=error` passes on it.
- **The fork's `MODULE.bazel.lock` left out of the patch:** safe for us. Bazel reads only the root module's lockfile, so consumers (our `git_override`, and the repro's `local_path_override`) never read it. That's why `test --lockfile_mode=error //...` and the repro pass. I confirmed that it is stale for the fork itself: `bazel mod deps --lockfile_mode=error` in the patched fork fails with "input to the extension '@@//dart/pub:extensions.bzl%pub' changed: … dart/ext/pubspec.lock". So upstream CI in error mode would need the refresh. The upstream README says so and leaves it to the maintainers' Linux refresh. Leaving it out also keeps a large conflict-prone file out of every queued patch, which helps the combined queue.

### AC4: upstream draft
- `DART=~/fvm/versions/3.47.7/bin/dart BAZEL=<bazelisk, own output base> documents/upstream/U-D-retrofit/repro.sh --compare <my patched fork>`: exit 0. `//:characters_api_test PASSED` ran fresh ("Executed 1 out of 1"), and `character.g.dart`, `envelope.g.dart` and `characters_api.g.dart` were all `EQUAL`.
- `MC_RULES_FORK=… tool/checks/T-0027-AC4_upstream_draft.sh`: PASS, "exit 0; 3 EQUAL, 0 DIFFER" ([verifier/T-0027-AC4.md](verifier/T-0027-AC4.md)).
- The README has a Conventional-Commit title, a `Changelog:` line (69 chars, with backticks), and Repro, Versions and patch link sections.

## Test-integrity audit
- **AC → test/evidence IDs:** AC1 (check script plus 3 test cases named `T-0027-AC1 …`), AC2, AC3 and AC4 (check scripts `T-0027-ACn_*.sh` plus evidence files). Every AC is covered.
- **Tests deleted, skipped or weakened:** none. The branch modifies only `MODULE.bazel`, `MODULE.bazel.lock`, the root `pubspec.*`, the overlay `pubspec.*` and the task file; everything else is added. No removed `test(`/`expect` lines.
- **Lint suppressions:** no `// ignore:` and no `ignore_for_file`. `tags = ["no-dart-analyze"]` on the intermediate `_stage_frz` is the plan 03 §3.4 staging pattern, with an explanatory comment. `tags = ["manual"]` is on the fork's direct-test subject, as its sibling direct tests have.
- **Golden files:** none.
- **Patch matches the fork export:** I checked out my own fork (0001 applied with `git am`) and ran `tool/rules_fork.sh export ai_rules_dart`. `git status` was clean afterwards, so the committed 347-line patch is byte-identical to the export.

## Diff review (branch vs `origin/main`)
Every change belongs to T-0027: the two spike packages, the overlay pubspec additions with the F-0011 pins kept, the root lock gaining `retrofit 4.10.0`, the patch and its `MODULE.bazel` line, the checks, the evidence, F-0025/F-0026, the upstream draft and the task file. I found no unrelated changes. The crew file-ownership rules are respected (no STATUS, BOARD, journal or index edits).

## Interaction with patches 0002 (T-0028) and 0003 (T-0029)
I didn't verify those patches, only replayed them. Script: `git am` on pin `e7163aa`, using the branch heads `6e30a36` (T-0028) and `a4e984b` (T-0029):

| Queue order | Result |
|---|---|
| 0002 alone / 0003 alone / 0002+0003 | apply |
| **0001 → 0002** | **fails:** `patch failed: docs/ext.md:46` |
| **0001 → 0003** | **fails:** `patch failed: dart/ext/pubspec.lock:217` |
| 0001 → 0002 → 0003 | fails at 0002 |

- 0002 and 0003 were exported against the bare pin, not on top of 0001. Whichever merges second must `checkout` the queue that's now on `main`, re-apply its commit in the fork and re-export, or `rules_fork.sh check` will fail.
- Bazel's lenient patcher could also fuzz them in silently (F-0022).
- All three patches touch `dart/ext/pubspec.yaml` and `pubspec.lock`. The combined ext lock must be **re-resolved** (`pub get` with all three generators), not text-merged, and then re-checked for analyzer 14.5.0 and "nothing else moves".
- T-0027 and T-0029 both rewrite the root `MODULE.bazel.lock`, `MODULE.bazel` `patches` and `tool/build_runner_overlay/pubspec.{yaml,lock}`. Regenerate the lock with `bazel mod deps --lockfile_mode=update` after each merge; don't hand-merge it.
- Patch 0001 inserts `retrofit_generator` between `json_serializable` and `mockito` (patch line 101), out of alphabetical order. That's harmless, but the neighbouring context lines are the ones the other patches also anchor on.
- T-0028's branch has its own `injectable_reference.sh` that "fails on build errors", while `spike_reference.sh` still has P-024. Consider fixing P-024 once, in the shared script.

## Issues found
1. **(major) The AC1 check passes on a failed Bazel build.** `tool/build_runner_overlay/spike_reference.sh:34` ends the build with `… | grep … || true` (P-024, still open, due before P3-03). `tool/checks/T-0027-AC1_retrofit_matches_build_runner.sh:15-38` doesn't check the build status independently, and its filter at `:16` drops the `ERROR` lines. Repro: add `config = "{not json",` to `_characters_api_retrofit_part` in `spike/retrofit_api/BUILD.bazel`. The Bazel `DartCodegen` fails with exit 2, yet the AC1 check prints five `EQUAL` lines and `**PASS T-0027-AC1**` (stale `bazel-bin`). Details: [verifier/build-failure-masking.md](verifier/build-failure-masking.md). Fix: capture the build's exit status (`${PIPESTATUS[0]}`) and exit 1 on failure.
2. **(minor) Wrong evidence file for F-0025.** `documents/evidence/T-0027/engineer/f0025-bare-freezed-diff.log` holds a T-0028 injectable build log (`//spike/di_sample:di_config_unresolved_init`, worktree `agent-a95ec7ad190c950c1`), not the bare-`@freezed` diff. F-0025 links it at `documents/findings/F-0025-freezed-json-autodetect-fails-under-bazel-shim.md:6` and `:18`. The finding itself is correct: I reproduced it (DIFFER ×2, `characters_api.g.dart` EQUAL). Replace the log.
3. **(minor, queue fragility, not a T-0027 code defect)** Patches 0002 and 0003 don't apply on top of 0001 (see the table above). Plan the rebase and the joint ext-lock re-resolve at integration.
4. **(info)** The fork's own `MODULE.bazel.lock` is stale with 0001 applied (confirmed in error mode). It's safe for consumers and documented in the upstream draft.

## Notes for the Tech Lead
- Re-verify only AC1 after fixing defect 1, ideally with the failure repro above as a negative case. Fix defect 2 at the same time. Everything else passed on `eee1877`.
- The 2 fork tests that fail to build (`dart/tests/defines_fixture`, exit 247) were not re-run by me. They have no `dart/ext` dependency.
