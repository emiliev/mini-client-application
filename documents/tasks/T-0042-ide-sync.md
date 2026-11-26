# T-0042: `tool/ide_sync`: generated code in the checkout for the IDE, `flutter run` and debugging (P3-10)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-26 `923b34a`; Verifier PASS `12723f0`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (tooling; ADR-0011) |
| Branch | `fleet/T-0042-ide-sync` |
| Created | 2026-11-26 |
| Depends on | T-0014 (Bazel toolchain), T-0033 (`prepare_pub_project.sh`, which already finds the codegen outputs with `cquery`) |
| Related | plan 03 KD11 and §7.1, P3-10, P-044, R10, R13, R28, F-0021, F-0032 |

## Goal
Bazel generates all codegen into `bazel-bin/`, and nothing generated is committed (R10). As a result, the IDE analyzer shows errors on every generated part, and `fvm flutter run`/debug against the repo doesn't work. `tool/ide_sync` copies exactly the Bazel-generated files next to their sources, git-ignored, so that the IDE, `flutter run`, breakpoints and hot reload all work on the real checkout. Bazel stays the source of truth for builds, tests and CI.

## Scope
- **In:**
  - `tool/ide_sync [--watch] [--link] [--env <env>] [<package>...]`, as in plan 03 §7.1:
    1. Build every codegen target, or the ones for the named packages. Add an aggregate target `//:all_codegen` if it helps.
    2. List the outputs with `cquery --output=files`, reusing the approach in `prepare_pub_project.sh`.
    3. Copy each output to `<pkg>/<rel>` only if its bytes differ.
    4. Delete files from the previous `.dart_tool/mc_ide_sync.manifest` that are no longer produced.
    5. With `--env`, write `app/*/assets/app_config.json` (R13).
    6. Make sure `fvm flutter pub get` works and `flutter run` can start `app/mini_client` from the checkout.
    7. `--watch` re-syncs on source changes, using `fswatch` if present and polling otherwise.
    8. `--link` uses symlinks, as an A/B option.
  - Guards:
    - `.gitignore` covers every synced path, and **no synced file can be committed**: a check fails if one is tracked.
    - BUILD globs exclude the synced suffixes, so `bazel build` and `test` are byte-identical with and without a sync.
    - Never write a path listed in the R28 fallback manifest.
  - Docs: a short "Developing" section in the root README (or `documents/`) covering:
    - first run (`tool/ide_sync --env dev`, then open in the IDE, then `fvm flutter run -d <simulator>`);
    - watch mode;
    - what to re-run after which change.
  - Optional, if cheap: make `tool/e2e/prepare_pub_project.sh` reuse `ide_sync`'s output listing.
- **Out:** a Bazel-native JIT and hot-reload loop (Phase F, P4-12) and IDE plugins.

## Acceptance criteria
- **T-0042-AC1:** On a fresh clone, after `tool/ide_sync --env dev`, `fvm dart analyze` (or `fvm flutter analyze`) over the workspace packages reports **zero** errors about missing generated parts. Before the sync it reports them; show both runs.
- **T-0042-AC2:** After the sync, `fvm flutter run -d <own simulator>` (or `flutter build ios --simulator`) for `app/mini_client` starts from the checkout. A screenshot shows the home screen. The simulator is your own and is deleted afterwards.
- **T-0042-AC3:** Incremental and stale handling:
  - A second sync with no source change copies 0 files; mtimes are unchanged.
  - Editing one freezed model re-copies only that model's outputs.
  - Removing a model deletes its synced outputs (manifest).
  - `--watch` picks up an edit within 5 s.
- **T-0042-AC4:** Safety:
  - `git status --porcelain` is clean after a sync (everything ignored).
  - A check fails if any synced output is tracked, or if a BUILD glob would pick one up. Give it a negative control.
  - `bazel test //...` and the T-0032 byte-identity check pass with synced files present, and the build's outputs are identical to a run without them.
- **T-0042-AC5:** Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check` and format all pass, and the script has tests: a shell test or a Dart test of its core, with fixtures.

## Log
- 2026-11-26: Created and dispatched (TL). The PO asked how to build, debug and run when generated code isn't in the repo.
- 2026-11-26: Engineer (Sonnet). Built `tool/ide_sync`, the `.gitignore` entries, `MC_GENERATED_DART` glob exclusions in the 7 packages with codegen, the pubspec `assets:` entry of the two apps, the "Developing" section (new root `README.md`) and five checks `tool/checks/T-0042-AC{1..5}_*.sh`. Two findings changed the design: a synced file in a package glob fails the build (rules_dart's duplicate-path error), and gen-l10n must be left to `flutter pub get` (see [F-0041](../findings/F-0041-ide-sync-generated-code-in-checkout.md)).

## Outcome
- **What it is:** `tool/ide_sync [--watch] [--link] [--env <env>] [--no-pub] [--clean] [<package>...]` (a single bash 3.2 script). It runs `bazel query` for the `dart_codegen` and `dart_aggregate_codegen` kinds (not `manual`), builds those labels, lists their outputs with `cquery --output=files`, keeps `.g.dart`, `.freezed.dart` and `.config.dart` (23 files today), checks every destination is git-ignored and untracked (otherwise it refuses and writes nothing), skips the R28 fallback manifest paths, copies only changed bytes (temp file and rename), deletes manifest entries that are no longer produced (never a tracked file), writes `.dart_tool/mc_ide_sync.manifest`, then runs `fvm flutter pub get`. With `--env` it also writes `app/*/assets/app_config.json` from `tool/bazel/config/<env>.json` and, once, the git-ignored Xcode scaffolding that `flutter create --platforms=ios` adds (Xcode project, xcconfigs, bridging header, launch image), taken from a scratch copy so no tracked file changes. `--link` makes symlinks. `--watch` uses `fswatch` if present, else polls every second (`fswatch` is not installed here, so the polling path is the one measured).
- **AC map and evidence** (`documents/evidence/T-0042/engineer/`):
  - **AC1** `tool/checks/T-0042-AC1_analyzer.sh` ([report](../evidence/T-0042/engineer/AC1_analyzer.md), `AC1_analyze-before.txt`, `AC1_analyze-after.txt`): fresh `git clone` at HEAD, fresh Bazel output base. Before: 176 errors, 11 warnings (`uri_has_not_been_generated`, `uri_does_not_exist`, `undefined_*`, ...). After `tool/ide_sync --env dev` (10 s): 0 errors, 0 warnings. Negative control: deleting `character.freezed.dart` gives 14 errors again.
  - **AC2** `tool/checks/T-0042-AC2_flutter_run.sh` ([report](../evidence/T-0042/engineer/AC2_flutter_run.md), `AC2_home.png`, `AC2_flutter_run.log`): own simulator `mc-T-0042-engineer-<pid>` (iPhone 17 Pro, iOS 26.2, deleted at the end), `fvm flutter run -d <udid>` from `app/mini_client`, VM service up, the home screen is on screen (title "Mini Client", "Config: env=dev" proves the synced asset was bundled), hot reload reports `Reloaded 0 libraries in 67ms`. Negative control: without `assets/app_config.json` the run fails to build.
  - **AC3** `tool/checks/T-0042-AC3_incremental.sh` ([report](../evidence/T-0042/engineer/AC3_incremental.md)): a second sync copies 0 of 23 files and every mtime is unchanged; editing `Character` copies exactly its one `.freezed.dart`; adding a model adds one file, removing it deletes the file and its manifest line (`removed=1`); `--watch` picked up an edit in 2.5 to 3.0 s. Negative controls for the mtime comparison and the "only that model" expectation. Timings (M4 Pro, warm disk cache): full first sync 5.5 s; no-op sync 1.5 to 1.9 s; an edit of a model 9.3 s the first time (the freezed action runs), 1.6 to 2.0 s when the action result is in the disk cache; fresh output base 10 s.
  - **AC4** `tool/checks/T-0042-AC4_safety.sh` ([report](../evidence/T-0042/engineer/AC4_safety.md)): `git status` identical before and after a sync; none of the 23 synced files is tracked; `bazel query 'kind("source file", deps(//...))'` finds none of them (nor the 6 gen-l10n files) as a source of any target; with the synced tree, `build //...` and `test //...` run **no action and no test** (all cached, so the action and test keys are unchanged) and the SHA-256 of all 27,610 files under `bazel-bin` equals the unsynced run's. Also `bazel test //... --nocache_test_results` on the synced tree: 101 of 101 pass (`test_uncached_synced.txt`). Negative controls: a stray un-ignored file changes `git status`; `git add -f` of a synced file is reported as tracked; a planted `.g.dart` in a package without the exclusion shows up as a source file and makes a build run actions.
  - **AC5** `tool/checks/T-0042-AC5_script_tests.sh` ([report](../evidence/T-0042/engineer/AC5_script_tests.md)): 44 fixture tests of the script's core, with no Bazel (first sync, no-op sync and mtimes, one-file change, stale deletion, tracked and non-ignored destination refused with nothing written, R28 fallback skip, `--link`, package scope, tracked file in a manifest never deleted, `--clean`, `--env` asset, bad arguments, `--watch`), plus a harness negative control. `tool/checks/T-0042-AC5_gates.sh` ([report](../evidence/T-0042/engineer/AC5_gates.md)), run on the synced tree: `test //...`, `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, the script tests and the T-0032-AC6 byte-identity with build_runner, all PASS.
- **Bazel changes (cross-cutting, glob exclusions only):** `MC_GENERATED_DART` in `tool/bazel/defs.bzl`, used by the globs of `app/mini_client`, `universe_wiring`, `characters_list`, `mc_api_client`, `mc_paging`, `spike/hello` and `spike/di_sample` (it replaces their ad hoc lists). A package without codegen needs nothing. A new package with codegen must use it, and `T-0042-AC4_safety.sh` fails when one does not. **T-0041 (`comics_details`) will need it** in its new BUILD's globs.
- **Other changes:** root `.gitignore` (config asset, Xcode scaffolding, `Podfile*`, `.metadata`); `assets: - assets/app_config.json` in the pubspec of `mini_client` and `universe_sandbox` (the Flutter tool only; Bazel bundles its own genrule output of the same name, proven by the byte-identity run); new root `README.md` with the "Developing" section.
- **Not done:**
  - No `//:all_codegen` target. The script finds the targets by rule kind with `bazel query`, which needs no list to maintain; an aggregate would have to list every label.
  - `prepare_pub_project.sh` still has its own listing (a scratch copy for e2e, covered by its own check). Reusing `ide_sync` there is a cheap follow-up now that the listing is proven twice.
  - gen-l10n output is not synced; Flutter writes it (F-0041 fact 2).
- **Test integrity:** no test deleted, skipped or weakened; no `// ignore:`. The characters_list and mc_paging architecture tests read the same sources as before (the globs only gained exclusions).
- **Follow-ups for the TL:** (1) buildgen (P2) should emit `exclude = MC_GENERATED_DART` in every generated BUILD; (2) T-0041's BUILD needs the same exclusion before merge, else `T-0042-AC4_safety.sh` and the build fail on a synced tree; (3) the `fvm flutter` baselines (plan 03 §7.3, `--dest`) were not built: `ide_sync` writes into the checkout only; (4) `ide_sync` could replace the listing in `prepare_pub_project.sh`; (5) plan 03 §7.1 describes `--dest <tree>`; this task used `MC_IDE_SYNC_ROOT` for tests instead.

### Review round (code review: 7 important, 3 cheap)
1. `prepare_pub_project.sh` now adds `assets:` only when the pubspec lacks it (the old script on the new pubspec fails: `e2e_prepare_old_script_fails.txt`). `T-0033-e2e_prepare.sh` PASS (`T-0042-...` copy `T-0033-e2e_prepare.md`) and `tool/e2e_ios.sh` journey `characters_journey_test` PASS on my own simulator (`e2e/`).
2. `place()` removes its temp file and fails on a failed write, copy and link (AC5 test 15, read-only directory).
3. The cquery path is used as printed, never `ls bazel-out/*/bin | head -1` (test 16, a stale copy in a config that sorts first).
4. `missing` and `skipped` are cleared at the start of every sync (test 17, two cases, in watch mode).
5. Every Xcode item is checked against `.gitignore` before the first is written (test 18; template hook `MC_IDE_SYNC_IOS_TEMPLATE`).
6. The watch fingerprint and the fswatch filter include `pubspec.yaml`, `l10n.yaml` and the config dir (test 20, a config edit refreshes `app_config.json`).
7. The watch baseline is taken before the first sync (test 20, `MC_IDE_SYNC_TEST_DELAY`).
8. The Xcode scaffolding is recorded in `.dart_tool/mc_ide_sync.scaffold` and removed by `--clean` (test 19); README says gen-l10n is left alone.
9. The `manual` tag is matched as a whole tag (`T-0042-AC3` step e, real Bazel: `manual_check` is synced, `manual` is not).
10. `ide_sync` reads `MC_GENERATED_DART` from `tool/bazel/defs.bzl` for its sync filter and the watch filter (so a hand-named `lib/src/app.config.dart` is a source; test 16 and 20).
Each fix was mutation-checked: reverting it makes its test fail (`review_mutations.txt`; item 9 by hand: the unanchored regex fails AC3 step e).
A fifth finding of the round (not in the review): `cquery` can name another configuration after a `bazel test`; `ide_sync` now reads the outputs from the build event stream (F-0041 fact 5; `T-0042-AC3` step 0 runs a test first).

## Merge (TL)
- 2026-11-26: Review-first (ADR-0011): `/code-review` found 7 important bugs, among them the e2e pipeline broken by a duplicate `assets:` key, a failed write reported as success, and stale outputs from another configuration. The engineer fixed them and found one more on the way: after `bazel test`, `cquery` lists outputs of the test-transition configuration, so outputs now come from the BEP. Single Sonnet Verifier pass: FAIL `8c74763`, on one check-script defect (the AC4 exact file-set compare failed on a fresh output base). Fixed in `351e732` (hash-equal subset plus 0 actions); narrow Sonnet re-verify PASS `12723f0` (about 91k and 103k tokens). The TL merged `--no-ff`; on the merge result `check` passed, 101/101 tests, lint was clean, `mc_arch_check` reported OK and the fixtures check passed.
- **Developer workflow now:** `tool/ide_sync --env dev`, then open the IDE and run `fvm flutter run`. `--watch` re-syncs on save. See the root `README.md`, "Developing".
