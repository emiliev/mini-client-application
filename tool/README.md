# tool/

Scripts used by Engineers and Verifiers. All of them run on the macOS default `/bin/bash` (3.2) and need only Xcode (`xcrun simctl`, `sips`), FVM and `/usr/bin/python3` (used to parse `simctl` JSON). Nothing has to be installed.

## `e2e_ios.sh`: e2e tests on a private iOS simulator

Runs a Flutter project's `integration_test` targets on a simulator that it creates for this run only, collects screenshots and logs as evidence, and always deletes the simulator ([T-0012](../documents/tasks/T-0012-ios-sim-e2e-runner.md), [ADR-0006](../documents/adr/0006-verification-strategy.md) §5 and §6, [F-0004](../documents/findings/F-0004-ios-verification-pipeline.md)).

```sh
tool/e2e_ios.sh --task T-0010 --role engineer --project .
tool/e2e_ios.sh --task T-0010 --role verifier --project . \
    --target integration_test/browse_test.dart --device "iPhone SE (3rd generation)" \
    --runtime com.apple.CoreSimulator.SimRuntime.iOS-18-2
```

| Option | Default | Meaning |
|---|---|---|
| `--task T-XXXX` | required | Task ID. Used in the simulator name and the default evidence dir. |
| `--role engineer\|verifier` | required | Used in the simulator name. |
| `--project <dir>` | required | Flutter project (must contain `pubspec.yaml`). The runner runs from here. |
| `--target <file>` (repeatable) | every `integration_test/*_test.dart` | Target files, relative to the project. |
| `--driver <file>` | `test_driver/integration_test.dart` | Host-side driver. Checked only if the runner command uses `{driver}`. |
| `--device <name or id>` | `iPhone 17 Pro` | Simulator device type. |
| `--runtime <id>` | `com.apple.CoreSimulator.SimRuntime.iOS-26-2` | Simulator runtime. |
| `--evidence-dir <dir>` | `<repo>/documents/evidence/<task>/<role>` | Where the summary, logs and screenshots go. One dir per role, so Engineer and Verifier runs never overwrite each other. |
| `--runner-cmd "<cmd>"` | `fvm flutter drive --driver={driver} --target={target} -d {udid}` | Command run once per target. `{target}`, `{driver}` and `{udid}` are replaced (shell-quoted); `$SCREENSHOT_DIR` is exported. |
| `--keep-sim` | off | Don't delete the simulator; the script prints how to delete it. |

What it does:
1. **Pre-flight** (before any simulator exists): checks `xcrun`, `sips`, `pgrep`, `fvm` (only if the runner command uses it), the project, targets and driver, that the runtime exists and is available, that the device type exists, and that the runtime supports it. A bad value fails in about a second, with exit code 2 and the bad value in the message.
2. Prepares the evidence dir. It belongs to the run: the previous run's outputs there (`e2e-summary.md`, `e2e-*.log`, `*.png`) are removed, so no stale screenshot lingers, and any other file is kept. A dir that holds PNGs but no `e2e-summary.md` written by this script is refused (exit 2), because those PNGs belong to someone else.
3. Creates `mc-<task>-<role>-<pid>` with `simctl create` (never `clone`), boots it and waits with `simctl bootstatus -b`.
4. Runs each target with `SCREENSHOT_DIR` set to a per-target temp dir. The output goes to `e2e-<target-basename>.log` (for example `e2e-app_test.log`) in the evidence dir. A failing target prints the last 30 lines of its log and the script carries on with the next target.
5. Copies each screenshot into the evidence dir. It is downscaled with `sips -Z 1200` **only if it is taller than 1200 px**; anything else is copied byte for byte. If a name is already taken in this run, the later file is saved as `<target-stem>-<name>.png`, then `<target-stem>-3-<name>.png` and so on until it is unique; log names work the same way (`e2e-<stem>-2.log`, …). If a screenshot can't be written, the run stops with exit 4 and the file is not listed in the summary.
6. Writes `e2e-summary.md`: result, task, role, device, runtime, simulator name and UDID, runner, per-target result, duration and log, and the screenshots with their original size. It is rewritten after each target, so an interrupted run still leaves a summary (`INTERRUPTED (SIGINT)`).
7. A `trap` on `EXIT`, `INT` and `TERM` stops the runner (it runs in its own process group, so children that were re-parented are killed too; SIGTERM, then SIGKILL after 5 s), keeps the interrupted target's log link and any screenshots it had already taken, then shuts down and deletes the simulator. During teardown, further SIGINT and SIGTERM are ignored, so a second Ctrl-C can't leave the simulator behind. `SIMULATOR_DELETED_AT=` is printed only once a fresh listing confirms the deletion.

Machine-readable lines on stdout: `SIMULATOR_NAME=`, `SIMULATOR_UDID=`, `SIMULATOR_CREATED_AT=` and `SIMULATOR_DELETED_AT=` (epoch seconds).

Exit codes: `0` all targets passed, `1` at least one target failed, `2` bad arguments or failed pre-flight (no simulator created), `3` simulator setup failed (or its deletion couldn't be confirmed), `4` evidence (log, screenshot or summary) couldn't be written, `130` / `143` interrupted by SIGINT / SIGTERM.

Timings on this Mac (iPhone 17 Pro, iOS 26.2): pre-flight about 1 s, boot about 16 s, first `flutter drive` of a project about 30 to 45 s (cold Xcode build), later runs about 15 s, teardown about 1 s. The first run after a Flutter SDK change also downloads the SDK's iOS artifacts and migrates the project, which took about 65 s on its own.

Notes:
- Parallel runs are safe as long as each uses its own project folder (own `build/`), which separate worktrees give you (F-0004 gotcha 8).
- To send SIGINT to a run started in the background from another script, enable job control (`set -m`) before starting it: otherwise bash starts background jobs with SIGINT ignored and nothing can trap it ([F-0005](../documents/findings/F-0005-bash-background-jobs-ignore-sigint.md)). SIGTERM always works.
- `kill -9` skips the trap and leaves the simulator behind: use `sim_cleanup.sh`.

## `sim_cleanup.sh`: delete orphaned fleet simulators

```sh
tool/sim_cleanup.sh --dry-run   # list what would be deleted
tool/sim_cleanup.sh             # shut down and delete every simulator named mc-*
```

Deletes only simulators whose name starts with `mc-`; every other simulator is left alone. `--device-set <dir>` works on a custom `simctl --set` device set instead of the default one (the test suite uses this). **It also deletes the simulator of an e2e run that is still in progress**, so only run it on the default set when no `e2e_ios.sh` is running. If the simulators can't be listed (`simctl` fails or returns bad JSON), it exits 3 instead of reporting "nothing to delete". Exit codes: `0` done, `1` a simulator couldn't be deleted, `2` bad arguments, `3` listing failed. Takes about 1 s plus 1 s per simulator.

## `test/e2e_ios_test.sh`: tests for both scripts

```sh
tool/test/e2e_ios_test.sh            # all tests, one per T-0012 acceptance criterion
tool/test/e2e_ios_test.sh AC5 AC7    # only tests whose name contains AC5 or AC7
E2E_TEST_KEEP=1 tool/test/e2e_ios_test.sh AC1   # keep the temp dir (fixtures, outputs, evidence)
```

The suite creates a throwaway Flutter app in a temp dir (`fvm flutter create`, a 2-screen app with keyed list items, an `integration_test` that takes 2 screenshots, a failing variant, and a screenshot driver), so nothing large is committed. It runs the scripts with `/bin/bash` 3.2 (override with `E2E_TEST_BASH`), prints `PASS` or `FAIL` per test and a summary, and exits non-zero if any test fails. On exit, even after a failure or Ctrl-C, it stops its background runs and deletes every simulator it created. The AC6 test works on a private device set, so it never deletes another agent's live `mc-` simulator.

| Test | Covers | Time |
|---|---|---|
| `test_T-0012-AC1_pass_run_collects_evidence` | passing run: exit 0, 2 PNGs at most 1200 px tall, summary shows PASS, log saved | about 50 s (includes the cold build) |
| `test_T-0012-AC2_failing_target_reports_fail` | failing run: exit 1, summary shows FAIL, failure log saved | about 50 s |
| `test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint` | no `mc-T-0012-*` simulator after a pass, a fail and a SIGINT during `flutter drive`; runner processes are gone | about 100 s |
| `test_T-0012-AC4_parallel_runs_isolated` | engineer and verifier runs at the same time on two fixture copies: both pass, different simulators, overlapping lifetimes | about 70 s |
| `test_T-0012-AC5_bad_runtime_or_device_fails_fast` | bad `--runtime` and bad `--device`: exit 2 in under 10 s, message names the value, no simulator | about 1 s |
| `test_T-0012-AC6_cleanup_only_mc_simulators` | `sim_cleanup.sh` deletes booted and shut-down `mc-` simulators, keeps the control one; `--dry-run` deletes nothing | about 20 s |
| `test_T-0012-AC7_small_screenshot_not_upscaled` | images of 600 and 1200 px are copied byte for byte, 1800 px is shrunk to 1200; also end to end through a stub `--runner-cmd` | about 20 s |

Regression tests for the code-review findings, each named after the AC it protects:

| Test | Covers | Time |
|---|---|---|
| `test_T-0012-AC1_unwritable_screenshot_is_an_error_not_a_phantom` | a screenshot that can't be written (both the `cp` and `sips` paths) gives exit 4 and no summary entry | about 20 s |
| `test_T-0012-AC1_multiple_targets_get_unique_names` | 3 targets whose renamed logs and screenshots would collide all get unique names | about 20 s |
| `test_T-0012-AC3_teardown_survives_second_sigint_and_kills_orphans` | Ctrl-C (SIGINT to the process group), then a second one 1 s later during teardown: the simulator is still deleted; a re-parented, TERM-ignoring child of the runner is killed; the interrupted row links its log and keeps the screenshot already taken | about 30 s |
| `test_T-0012-AC4_default_evidence_dir_is_per_role_and_reset` | without `--evidence-dir`, engineer and verifier write to `<task>/engineer` and `<task>/verifier`; stale outputs are removed and other files kept; a dir of foreign PNGs is refused | about 30 s |
| `test_T-0012-AC5_fvm_checked_only_when_runner_uses_it` | without `fvm` on PATH, the default runner fails pre-flight but `--runner-cmd true` doesn't | about 1 s |
| `test_T-0012-AC6_cleanup_fails_loudly_when_listing_fails` | a failing or garbage `xcrun simctl list` (fake `xcrun` on PATH) gives exit 3, not "nothing to delete" | about 1 s |

The whole suite takes about 7 to 8 minutes.

## `rules_fork.sh`: patch queue for the rules forks

Develops fixes and shims for `ai_rules_dart` / `ai_rules_flutter` in a local clone and exports them as numbered patches in `third_party/rules_patches/<repo>/` ([T-0024](../documents/tasks/T-0024-rules-patch-queue.md), plan 03 KD2). Conventions and the full workflow: [third_party/rules_patches/README.md](../third_party/rules_patches/README.md).

```sh
tool/rules_fork.sh checkout ai_rules_dart   # clone pin, apply queue, write .bazelrc.user (absolute --override_module)
tool/rules_fork.sh export ai_rules_dart     # fork commits (pin..HEAD) -> NNNN-slug.patch; refuses binary hunks
tool/rules_fork.sh status
```

Test: `tool/test/rules_fork_test.sh` (local fake upstream, real Bazel, no network).

**`check` must run before merging any queue change.** `tool/rules_fork.sh check [<repo>]` replays every queued patch on the pinned commit with `git am` (strict, no fuzz) and exits non-zero naming the first bad patch. Bazel's own patcher is lenient and can silently drop a stale hunk (F-0022), so a green build proves nothing about the queue. It uses the fork dir or a pin cache (`~/.cache/mc-bazel/pins`, `MC_PIN_CACHE`) and fetches the pin only when neither has it. The TL wires it into the verify gate.
