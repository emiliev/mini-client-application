# T-0062: Tooling hygiene: format gate coverage, gates in fresh worktrees, e2e bundle id and names, and the sheet handle pin (P-101, P-108, P-109, P-111, P-114a)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (tooling and tests; negative controls required; ADR-0011) |
| Branch | `fleet/T-0062-tooling-hygiene` |
| Created | 2026-11-27 |
| Depends on | T-0055 (`tool/e2e_ios.sh`), T-0058 (`mc_ds_overlays`) |
| Related | P-101, P-108, P-109, P-111, P-114(a); Q-004 (bundle id `com.emiliev.miniclient`); F-0055; `tool/README.md` |

## Goal
Clear five small items that keep tripping up agents. None changes product behaviour.

## Scope
- **In:**
  1. **P-109, bundle id.** Bazel builds `com.emiliev.miniclient` (`app/mini_client/BUILD.bazel:310`). The pub/e2e project made by `tool/e2e/prepare_pub_project.sh` (`flutter create --org com.emiliev`) installs as `com.emiliev.miniClient`.
     - Make the prepared project's `PRODUCT_BUNDLE_IDENTIFIER` `com.emiliev.miniclient` for every configuration. RunnerTests becomes `com.emiliev.miniclient.RunnerTests`.
     - Update `tool/checks/T-0042-AC2_flutter_run.sh:104` and every other place that hard-codes `miniClient`.
     - `tool/e2e_ios.sh` resolves the id from the project, so it should simply follow.
  2. **P-101 and P-111, the format gate.**
     - Add one shared gate helper, for example `tool/checks/lib/format_gate.sh`. It runs `fvm dart pub get --offline` at the root if `.dart_tool/package_config.json` is missing, so a fresh worktree passes. It formats exactly the repo's Dart sources: `utility/`, `feature/`, `app/`, and `tool/` including `tool/loc`. It excludes `third_party/` (vendored, must stay as patched) and `documents/`.
     - Reformat the 4 `tool/loc` files: formatting only.
     - Rename the 13 `.dart` files under `documents/evidence` to `.dart.txt`, and fix any links to them.
     - Afterwards a repo-wide `dart format --set-exit-if-changed` over the gated directories exits 0.
     - Document the helper in `tool/README.md`. Don't rewrite the old per-task gate scripts. Future gate scripts should call the helper.
  3. **P-108, e2e names and setup.**
     - `tool/e2e_ios.sh` accepts any `[a-z0-9-]+` role, such as `reverify`, in the simulator name `mc-<task>-<role>-<pid>`.
     - When the raw tree has no Xcode project, it prepares one through `prepare_pub_project.sh`, or fails with one clear message that names the command to run.
     - Document both in `tool/README.md`.
  4. **P-114(a), the sheet handle pin.**
     - Add a test in `mc_ds_overlays`. A dismissible sheet whose content has `PopScope(canPop: false)` must not close when the handle is tapped or when the VoiceOver activate action fires.
     - Show that the mutation swapping `maybePop` for `pop` is killed.
     - Also pin the plain toast's 4 s duration (P-114(b)). It is still showing at 3.9 s and gone after 4.1 s, plus the animation.
- **Out:** any product code change, Android, and CI.

## Acceptance criteria
- **T-0062-AC1 (P-109):**
  - On your own simulator, an e2e run of one target installs `com.emiliev.miniclient`. Check with `simctl listapps` or `get_app_container`.
  - The flutter-run check uses the same id.
  - `grep -rn miniClient tool app` finds nothing outside generated files.
- **T-0062-AC2 (P-101/P-111):**
  - In a brand-new worktree, with no `.dart_tool`, the format gate passes.
  - Negative control 1: an unformatted line in `tool/loc` makes it fail.
  - Negative control 2: an unformatted line in `third_party/flow_builder` does not make it fail. Revert both afterwards.
  - The flow_builder provenance check still passes.
- **T-0062-AC3 (P-108):**
  - `--role reverify`, or however roles are passed, creates `mc-T-0062-reverify-*` and deletes it.
  - A raw tree either gets prepared or fails with the clear message, and both paths are shown.
  - `tool/test/e2e_ios_test.sh` has new tests named `T-0062-AC3`, and all of its tests pass.
- **T-0062-AC4 (P-114):**
  - The two new `mc_ds_overlays` tests are named `T-0062-AC4`.
  - Both mutations are killed.
  - A 50-run flake check of `overlays_test` has 0 failures.
- **T-0062-AC5:**
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check` and `rules_fork.sh check` pass.
  - The mini_client e2e suite passes on your own simulator with the new bundle id. Delete the simulator afterwards.
  - `git diff --stat` shows no product `lib/` change outside `mc_ds_overlays/test`.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer implemented all five items (see Outcome). Own simulator `mc-T-0062-engineer-*` deleted; Bazel output base `/tmp/mc-ob-T-0062-engineer` shut down.
  - A first run of the full `e2e_ios_test.sh` stalled in `flutter drive` while I ran my own e2e run at the same time (Flutter tool contention). I killed it and re-ran it alone: 23/23 PASS.

## Outcome
All ACs met. Changes outside `tool/` and `mc_ds_overlays/test`: the evidence renames (13 files to `.dart.txt`) with their links in `documents/` (T-0029, T-0034, T-0036, T-0038, T-0039, T-0043 reports; F-0027; T-0029 task), and the new evidence in `documents/evidence/T-0062/engineer/`. No product `lib/` change.

| AC | Evidence |
|---|---|
| AC1 | `tool/e2e/prepare_pub_project.sh` and `tool/ide_sync` rewrite the id to `com.emiliev.miniclient` (RunnerTests: `...miniclient.RunnerTests`). The prepared pbxproj holds it in all 6 `PRODUCT_BUNDLE_IDENTIFIER` lines. On `mc-T-0062-engineer-68804`, `simctl listapps` showed `CFBundleIdentifier = "com.emiliev.miniclient"` and `get_app_container ... com.emiliev.miniclient` resolved. `T-0042-AC2_flutter_run.sh:104` uses the same id. `grep -rn miniClient tool app` finds nothing. Full e2e of mini_client: `AC1_AC5_e2e-summary.md`, `AC1_AC5_e2e_run.log` (13/13 PASS). `tool/checks/T-0042-AC5_script_tests.sh` (ide_sync tests) PASS. |
| AC2 | `tool/checks/lib/format_gate.sh`, `tool/checks/T-0062-AC2_format_gate.sh`, report `T-0062-AC2_format_gate.md`: a throwaway worktree with no `.dart_tool` passes (137 false changes without the pub get step); negative control 1 (`tool/loc`) fails the gate; control 2 (`third_party/flow_builder`, and a `.dart` under `documents/`) does not; provenance check fails while flow_builder is modified and passes after the revert; the worktree was removed. `tool/loc` reformatted (4 files, formatting only). |
| AC3 | `tool/e2e_ios.sh` accepts `[a-z0-9-]+` roles and has `preflight_xcode_project`. New tests `test_T-0062-AC3_*` (3); full suite 23/23 PASS (`e2e_ios_test_full.log`). Negative controls: reverting the role regex fails the role test; removing the xcodeproj preflight fails the raw-tree test. The `reverify` run created and deleted `mc-T-0062-reverify-<pid>`. Raw-tree path: fails once with exit 2 naming `tool/e2e/prepare_pub_project.sh`; prepared path: passes the check. I chose "fail with one clear message" over auto-preparing, since preparing needs Bazel and a scratch copy. |
| AC4 | Two tests in `overlays_test.dart` named `T-0062-AC4` (handle tap and semantics activate under `PopScope(canPop: false)`; plain toast up at 3.9 s, gone after 4.1 s). `tool/checks/T-0062-AC4_mutations.sh`, log `AC4_mutations.log`: `maybePop` to `pop` (tap, semantics, both) survives without the new tests and is KILLED with them. Toast 3 s: survives without the new tests, KILLED with them. Toast 5 s: killed by the new tests and also by the older 4/8 s test. 50-run flake check: 0 failures (`AC4_flake50.log`). |
| AC5 | `test --lockfile_mode=error //...`: 191/191 pass; `build --config=lint //...`, `mc_arch_check` ("OK"), `rules_fork.sh check`, format gate: all exit 0. The mini_client e2e suite passed 13/13 on the own simulator with the new id. |
