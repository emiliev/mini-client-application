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
