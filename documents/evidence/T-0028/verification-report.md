# Verification report — T-0028: injectable codegen under Bazel (two-stage shim, patch 0002)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0028-injectable-shim` @ `da8054f` (verified on the Verifier's worktree branch reset to `da8054f`; the task branch itself is checked out in the Engineer's worktree)
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0028-verifier` (own output base; shut down at the end). Builds used the pin + patch queue (no `.bazelrc.user` override), except the one fork negative control below.
- **Fork dir:** my own, `~/.cache/mc-bazel/forks/agent-ae26614f3d08a857b-f7e9102263/ai_rules_dart`
- **Simulator:** none (no UI, no e2e for this task)
- **Verdict:** **PASS**

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Patch queue | `tool/rules_fork.sh check` | `check ai_rules_dart: 1 patch(es) apply strictly on pin e7163aab8f91`; `ai_rules_flutter: queue empty, OK` |
| Tests | `tool/bazelw … test //...` | `Executed 0 out of 48 tests: 48 tests pass.` (all disk-cache hits, same action keys) |
| T-0028 tests, uncached | `test --nocache_test_results //spike/di_sample:di_sample_test @rules_dart//dart/ext/injectable:injectable_shims_test` | 2/2 PASSED; 2 + 7 cases, `All tests passed!` |
| Lint | `tool/bazelw … build --config=lint //...` | `Build completed successfully` (exit 0) |
| Architecture | `tool/bazelw … run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Format | `fvm dart format --output=none --set-exit-if-changed spike/di_sample` and the fork's `dart/ext/injectable/{lib,test,shim_*.dart}` | `Formatted 10 files (0 changed)`, `Formatted 4 files (0 changed)` |
| Root lock | `fvm flutter pub get --enforce-lockfile` | resolves; no tracked file changed |
| `MODULE.bazel.lock` | every build above ran with the default lockfile mode | lock unchanged after all builds (`git status` clean) |

`tool/verify.sh` does not exist yet; the gates above are its equivalent.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0028-AC1 | `.config.dart` equals build_runner's byte for byte | `tool/checks/T-0028-AC1_injectable_matches_build_runner.sh` → `tool/build_runner_overlay/injectable_reference.sh`; `//spike/di_sample:di_sample_test` (`T-0028-AC1 …`) | Yes. `cmp` of the config and every shard against a fresh build_runner run of **stock** pub.dev injectable_generator 3.1.3 (with lean_builder 1.2.2, `package_config.json` checked). The runtime test checks every registration kind. I also ran 3 mutations and a negative control (below) | **PASS** |
| T-0028-AC2 | Body edit means the aggregate is a cache hit | `tool/checks/T-0028-AC2_di_cutoff.sh`; re-derived by hand with my own exec-log parser | Yes. The aggregate has no spawn (an action-cache hit) after a body edit. It **does** re-run after an API change, so the cache isn't over-cached | **PASS** |
| T-0028-AC3 | Ext lock has analyzer 14.5.0 and no lean_builder | `tool/checks/T-0028-AC3_ext_lock.sh`; re-derived by hand | Yes, with one weak sub-check in the script (issue 2). I re-did that sub-check correctly | **PASS** |
| T-0028-AC4 | `[]` shard and the config still builds; an init that generates nothing fails | `tool/checks/T-0028-AC4_…sh`; `injectable_shims_test` (`T-0028-AC4 …` ×3); `di_sample_test` (`T-0028-AC4 …`) | Yes. Shard `[]`; both negative targets exit 1 and write no `.config.dart` | **PASS** |
| T-0028-AC5 | `check`, test, lint, `mc_arch_check` green; upstream drafts exist | Gates table; `documents/upstream/U-D-injectable/`, `documents/upstream/U-X-injectable-lean_builder/` | Yes | **PASS** |

### AC1: byte equality (my run)
```
$ MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0028-verifier tool/build_runner_overlay/injectable_reference.sh spike/di_sample   # rc=0
   analyzer "14.1.0", lean_builder "1.2.2"
  Built with build_runner/aot in 13s; wrote 6 outputs.
EQUAL   spike/di_sample/lib/src/di/di_initializer.config.dart  sha256 d373324740114210
EQUAL   …/badge.injectable.json (shard) 67d1bed6… · clock 673f48ec… · greeter e6539d73… · greeting_repository 0326782b… · sample_module a0f460f9…
EMPTY   …/plain_helper.injectable.json (shard): Bazel [] / build_runner none (expected)
$ cmp <overlay>/lib/src/di/di_initializer.config.dart <bazel-bin>/…/di_initializer.config.dart   → equal
```
Reference generator: `package_config.json` → `hosted/pub.dev/injectable_generator-3.1.3`, `lean_builder-1.2.2`, `build_runner-2.16.1`. The overlay lock's sha256 for injectable_generator is `24d525c6…`, the same archive I fetched in AC3.

The tricky cases F-0026 names are all present and match:
- **Staged barrel:** `aquery` of `_di_config_src_badge_inj` lists `spike/di_sample/lib/di_sample.dart` among the staged inputs. The config imports `package:di_sample/src/<file>.dart`, not the barrel.
- **Constructor taking `Dio`:** `Badge(…, Dio)`. The shard carries `"otherImports":["package:dio/src/dio.dart"]`, the same as build_runner's.
- **Comment-only file:** `plain_helper.dart` → shard `[]`, absent from the config.

**Mutations.** All were reverted afterwards; the tree is clean.

| # | Change | Result |
|---|---|---|
| M1 | New `@lazySingleton class BadgePrinter(Clock, Dio)` in `badge.dart` | rc=0, all `EQUAL`; config sha `d3733247…` → **`bf970710…`**, badge shard → `9a6c6281…` |
| M2 | `GreetingRepository` `@injectable` → `@LazySingleton()`; swapped `dio` / `appName` declaration order in `SampleModule`; new file `audit_log.dart` with `@Singleton(order: -1) AuditLog(Clock, Dio)`, added to `_INJECTABLE` | rc=0, all `EQUAL` (7 outputs); config → **`df240ae4…`**, `AuditLog` registered first |
| M3 | As M2, but `audit_log.dart` **not** added to `_INJECTABLE` | rc=1: `DIFFER … config.dart` (`-    gh.singleton<_i1004.AuditLog>(`). The comparison catches it; the Bazel build itself is silent (issue 3) |
| NC | Fork negative control: in my fork, `inner.build(BuildRunnerLibrariesStep(buildStep))` → `inner.build(buildStep)` in both builders, built via `--override_module` | rc=1: config `DIFFER` (`+import 'package:di_sample/di_sample.dart' as _i100;`, Badge registration moved) and all 5 shards `DIFFER`. This reproduces F-0026 §1 and shows the wrapper is what makes AC1 pass. The fork was reverted and the override removed |

### AC2: early cutoff (re-derived by hand)
Body-only edit in `badge.dart` (`render()` string, a different file from the Engineer's), then `build --remote_download_all --execution_log_json_file=… //spike/di_sample:di_config`:
```
DartCodegen  //spike/di_sample:_di_config_src_{badge,clock,greeter,greeting_repository,plain_helper,sample_module}_inj  cacheHit=False runner=worker   (6 spawns)
(no DartAggregateCodegen spawn: action-cache hit)
badge.injectable.json 67d1bed60eff0595 → 67d1bed60eff0595 · di_initializer.config.dart d373324740114210 → d373324740114210
```
API change (added `@lazySingleton BadgePrinter`), same command:
```
DartCodegen ×6 cacheHit=False
DartAggregateCodegen  //spike/di_sample:di_config  cacheHit=False  runner=worker  exit=0
badge shard → 9a6c628163543a28 · config → bf970710067f9b96 (contains gh.lazySingleton<_i146.BadgePrinter>)
```
The aggregate's package-local inputs (`aquery`) are the init file plus the 6 shards only; the hand-written `lib/src/*.dart` files are not among them. Every shard re-runs on any edit, because shards depend on `_stage` (F-0026 §5, a known follow-up). That doesn't affect the AC.

### AC3: ext lock and vendored generator (re-derived by hand)
- Fetched `@ai_rules_dart+/dart/ext/pubspec.lock`: analyzer `14.5.0`, `_fe_analyzer_shared` `109.0.0`, injectable `3.0.0`, **no lean_builder**. The patch's lock hunk adds only `injectable`.
- `fvm dart pub get --enforce-lockfile` on a copy of the patched `dart/ext` resolves, and the lock is unchanged.
- `query '@@ai_rules_dart++pub+ext_pub_deps//:all'` has `:analyzer` and `:injectable` but no `:lean_builder`; no `lean_builder` repo exists under `external/`.
- I downloaded `https://pub.dev/api/archives/injectable_generator-3.1.3.tar.gz` myself: sha256 `24d525c60ed9abf345c8749c3291ca1b3f1d21fd53344c0c644da820a92049df`, which equals pub.dev's API `archive_sha256`.
- `diff -r -x lean_builder <archive>/lib <vendored>/lib` shows no difference. The only extra entry upstream is `lib/lean_builder` (5 files). No vendored file imports `package:lean_builder`.
- Provenance (`VENDORED.md`): the upstream tag `injectable_generator-3.1.3` resolves to `0644204687dfb34e7318c11fe4abf9416ed2c549` on GitHub, which matches. `CHANGELOG.md` is identical. `pubspec.yaml` differs only in the commented-out lean_builder line. `LICENSE` gained a trailing newline (issue 4).

### AC4: empty and failing cases
```
plain_helper shard: []          :di_config build OK, config has 0 mentions of plain_helper
//spike/di_sample:di_config_without_init     rc=1  "Bad state: injectable config: testdata/di_without_init.dart generated nothing for testdata/di_without_init.config.dart. …"
//spike/di_sample:di_config_unresolved_init  rc=1  "Could not resolve annotation for `Future<void> _init(GetIt getIt, String? environment)`."
bazel-bin: only *.config.dart-0.params in both output dirs; no .config.dart written
```
Unit tests (`injectable_shims_test`) also cover a `[]` shard accepted, an empty shard rejected, a non-list shard rejected, and an init that generates nothing.

## Patch file vs fork export
`tool/rules_fork.sh checkout ai_rules_dart` → `export ai_rules_dart` produced `0001-ext-injectable-two-stage.patch`. Its content is **byte-identical** to the committed `0002-ext-injectable-two-stage.patch` (sha256 `ad5f5ac7a1e4a0c0…` for both); only the number differs, as the Engineer stated. The exported file was removed and the committed one restored. `git am` warns about one whitespace line (`patch:4448`), which is upstream's `pubspec.yaml` line 18 (`   `). That is vendored content and harmless.

## Test-integrity audit
- Every AC has a test or check named with its ID: AC1 (check script + `di_sample_test` case), AC2 (check script), AC3 (check script), AC4 (check script + 4 test cases), AC5 (gates). Engineer evidence is in `documents/evidence/T-0028/engineer/`.
- Tests deleted, skipped or weakened: **none**. The diff modifies only `MODULE.bazel`, `MODULE.bazel.lock`, `pubspec.yaml`, `pubspec.lock` and the task file; everything else is added.
- Lint suppressions added: **none**. The only `ignore_for_file` / `.skip(` hits in the diff are inside the vendored upstream generator (the text it emits into generated files, and `Iterable.skip`). `_stage` carries `no-dart-analyze` / `no-dart-format` tags, which is the existing staging pattern (V3-18); the same files are analysed through `:di_sample`.
- Golden files updated: none.

## Unrelated changes
None. Every changed file belongs to the task:
- `pubspec.yaml`: adds the workspace member `spike/di_sample`.
- `pubspec.lock`: adds `injectable 3.0.0` (+8 lines). It's `transitive`, because in a pub workspace only the root package's deps count as direct.
- `MODULE.bazel.lock`: 404 additions and 2 changed lines, all explained by injectable entering both locks:
  - the new `FILE:` hashes of `//pubspec.lock` and `@ai_rules_dart+//dart/ext/pubspec.lock`
  - the new repos `pub_deps__injectable` and `ext_pub_deps__injectable`
  - `"injectable"` inserted into the hubs' `lock_packages` / planned-deps lists

## Issues found
1. **(minor) The combined queue with T-0027 doesn't apply strictly as committed.** `git am` of T-0027's committed `0001-feat-ext-add-a-retrofit_generator-shim-and-retrofit_.patch` then T-0028's `0002` on the pin fails at `docs/ext.md:46`. T-0027 inserts `├── retrofit/` between `copy_with_extension_gen/` and `stacked/`, which is inside 0002's context. `dart/ext/pubspec.yaml`, `dart/ext/pubspec.lock` and everything else apply cleanly. With docs excluded, the combined ext lock passes `pub get --enforce-lockfile` unchanged, so it really is the union. The Engineer's note ("applies on T-0027's WIP fork commit") is stale against T-0027's final patch. Fix at merge: rebase 0002 onto 0001 in a fork (a one-line docs conflict), re-export, then `rules_fork.sh check`. (By F-0022, Bazel's fuzzy patcher might accept the drift, so don't rely on a green build.) `MODULE.bazel`'s `patches` list and the root `pubspec.yaml` workspace list will also conflict textually, trivially.
2. **(minor) The AC3 script's lean_builder target check is vacuous.** `tool/checks/T-0028-AC3_ext_lock.sh:24` queries `@ext_pub_deps//:lean_builder`, but `@ext_pub_deps` isn't visible from the main repo. The query always errors, so the check always reports "absent". The canonical `@@ai_rules_dart++pub+ext_pub_deps//:all` query (which I ran) confirms it is absent, so the AC holds. Only the script is weak.
3. **(minor) An annotated file that isn't listed is dropped silently.** `injectable_package`'s `srcs` (`spike/di_sample/BUILD.bazel:30-37`, `_INJECTABLE`) is hand-maintained. An `@injectable` file left out of it gets no shard, and its registration disappears from `.config.dart` without any build error (M3). build_runner would include it. This is buildgen's job (F-0026 implications), but it should be in `pending-work.md` explicitly, because it is a silent correctness gap.
4. **(minor) `VENDORED.md` says "LICENSE (unchanged)", but the vendored `LICENSE` gained a trailing newline** (upstream has no final newline: 1068 vs 1069 bytes). Patch: `dart/ext/injectable/third_party/injectable_generator/LICENSE`. Either say so under "Local changes" or keep the byte-exact file.
5. **(minor) `injectable_reference.sh` enumerates shards from `bazel-bin`, which can hold stale outputs.** `tool/build_runner_overlay/injectable_reference.sh:98` uses `find "$BAZEL_BIN/$PKG_DIR/lib" -name '*.injectable.json'`. After a source is removed from `srcs`, its old shard is still compared. During M3 it gave a false `EQUAL audit_log.injectable.json`, and after NC a false `MISSING in build_runner`. The config comparison stayed correct. Better to enumerate shards from the build's declared outputs (`cquery --output=files`).
6. **(minor) Finding-number collision.** T-0027's branch also adds `documents/findings/F-0026-retrofit-shim-spike-facts.md`. One of the two must be renumbered at merge. T-0028's number is also baked into upstream-bound fork code: patch line 342, `injectable_shims.dart` doc comment "`(F-0026)`". If you renumber, re-export the patch; better, drop the local finding ID from code meant for upstream.

## Notes for the Tech Lead
- The vendored generator's `recase`, `code_builder`, `dart_style` and `source_gen` are only **transitive** in the ext lock (via other generators). If one of those generators is dropped, the vendored generator loses a dependency. Consider making them direct in `dart/ext/pubspec.yaml` upstream.
- The shard stage re-runs all 6 shards on any edit (F-0026 §5). It's cheap here, but at 169 packages it is buildgen's narrowing job.
- None of the issues blocks merging T-0028 on its own. Issue 1 must be handled when the two patches are combined.
