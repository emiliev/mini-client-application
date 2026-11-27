# F-0055: `flutter drive` exits 0 after a failed Xcode build, so e2e reported PASS for code that did not compile

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0055)
- **Type:** Tooling bug, root cause
- **Related:** T-0055, T-0054 (found it), T-0012, ADR-0006, F-0004, F-0032

## Summary
`tool/e2e_ios.sh` read the runner's exit code correctly. The runner itself, `fvm flutter drive`, returned 0 although the target did not compile. After a failed Xcode build it **runs the app that an earlier target left behind** and reports that app's tests. Every e2e PASS taken after a compile error in a later target could be a different target's PASS.

## Reproduction (before the fix)
A scratch copy of `app/mini_client` (made with `tool/e2e/prepare_pub_project.sh`) with two throwaway targets: `zz_good_test.dart` (passes) and `zz_broken_test.dart` (`final int x = 'not an int';`). Run through the unmodified script on an own simulator, good first, broken second:

```
==> PASS integration_test/zz_good_test.dart (30 s)
==> PASS integration_test/zz_broken_test.dart (16 s)
==> RESULT: PASS (2 target(s))
```

Evidence: `documents/evidence/T-0055/engineer/before-fix/` (log of the broken target: lines 25 to 58, `exit code: 0`). The broken target's log reads, in order:

```
Failed to build iOS app
    ** BUILD FAILED **
    integration_test/zz_broken_test.dart:8:19: Error: A value of type 'String' can't be assigned to a variable of type 'int'.
    Target kernel_snapshot_program failed: Exception
Could not build the application for the simulator.
Application failed to start on attempt: 1
VMServiceFlutterDriver: Connecting to Flutter application ...
flutter: 00:00 +0: T-0055 good target          <- the OTHER target's test
flutter: 00:00 +2: All tests passed!
# exit code: 0
```

## Root cause
1. It is `flutter drive`, not the script's `rc` handling. The log's last line is `# exit code: 0`, written from the child's real status.
2. `flutter drive` treats the failed build as "Application failed to start on attempt: 1" and goes on to the next step: it installs and launches `build/ios/iphonesimulator/Runner.app`, which the previous target's successful build left in the project's `build/` dir, attaches to it over the VM service and runs the driver against it. The driver sees a green test run and exits 0.
3. **Uninstalling the app from the simulator is not enough.** With only `simctl uninstall` before each target, a broken target alone on a brand new simulator still ran the other target's test and exited 0 (evidence: `intermediate-uninstall-only-*`). The stale bundle comes from `build/ios/iphonesimulator/`, not from the simulator. Only deleting that directory removes the source of the false PASS; the task text asked only for the uninstall.

The bundle id the build installs under is `com.emiliev.miniClient` (from the Runner target in `ios/Runner.xcodeproj`, made by `flutter create --org com.emiliev`), not the lowercase `com.emiliev.miniclient` that Q-004 records (that spelling is used by the URL scheme in `Info.plist`). The script reads the id from the Xcode project instead of hard-coding either.

## Fix: two independent defences (both in `tool/e2e_ios.sh`)
1. Before each target: `simctl uninstall <udid> <bundle id>` and `rm -rf <project>/build/ios/iphonesimulator`. Xcode's intermediates (`build/ios/Debug-iphonesimulator`) stay, so builds remain incremental.
2. After each target: scan the log (skipping the 6 header lines the script wrote itself) for the markers in `E2E_BUILD_FAIL_MARKERS` and for the regex `\.dart:[0-9]+:[0-9]+: Error:`. A hit makes the target FAIL, whatever the exit code, with `FAIL (build failed: <marker>)` in the summary and a note line at the end of the log.

Markers: `BUILD FAILED`, `Error (Xcode)`, `Failed to build iOS app`, `Could not build the application`, `Error: Compilation failed`, `Application failed to start on attempt`, and a Dart compile error line. `Application failed to start on attempt` is the exact signature of the false PASS, so even a failure the other markers miss is caught.

Each defence was proven alone through the real script (T-0055-AC1e), by running a copy of the script with the other defence switched off:

| Run | Good, then broken target |
|---|---|
| Defence 1 only (marker scan off) | broken: FAIL, exit 1 (no app to attach to) |
| Defence 2 only (no uninstall, no delete) | broken: `FAIL (build failed: BUILD FAILED)`, although `flutter drive` exited 0 |
| Both | broken: `FAIL (build failed: BUILD FAILED)` |

## Not done: a positive identity check
The task suggested requiring a marker that names the target's own file. That needs every integration test to log it (11 files here), and with defence 1 a stale app cannot exist any more. Not worth the churn; revisit if a third false-PASS path appears.

## Lessons
- A PASS from `flutter drive` means "some app ran green", not "this target built". Check the log for build errors, never only the exit code.
- A throwaway broken target, run after a good one, is the cheap negative control for any e2e runner change.
- Defence by deleting `build/ios/iphonesimulator` costs only a re-copy of the app bundle, not a rebuild.
