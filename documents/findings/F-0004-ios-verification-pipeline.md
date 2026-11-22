# F-0004: The iOS verification pipeline works end to end on this Mac

- **Date:** 2026-11-22
- **Author:** crew: Engineer (spike T-0009); TL spot-check verification
- **Type:** Spike
- **Related:** ADR-0006, T-0009, T-0005, T-0010, [evidence](../evidence/T-0009/verification-report.md)

## Summary
Every ADR-0006 layer runs on this Mac with only Flutter (FVM 3.41.0), Xcode 26.2 and `xcrun simctl`, with no extra installs: widget tests, goldens (they fail on visual change), coverage, `integration_test` e2e on an agent-created simulator, in-test and out-of-test screenshots, and two simulators booted in parallel. A full cycle took about 5 minutes on a throwaway app. **Two caveats:** goldens render text as black boxes (the Ahem test font), and `simctl clone` fails on a booted device.

## Evidence: commands and timings
| Layer | Command | Result | Time |
|---|---|---|---|
| Create | `fvm flutter create --platforms=ios --org com.example --project-name verify_spike .` | OK | 1 s |
| L2 Widget | `fvm flutter test test/widget_test.dart` | 3 passed | 6.5 s |
| L3 Golden | `fvm flutter test --update-goldens test/golden_test.dart`, then without the flag | pass / pass | 2.7 s / 2.5 s |
| L3 Golden (break) | change the seed colour, then re-run | **fails**: "Pixel test failed, 100.00 %, 320000px diff"; diffs in `test/failures/` | 2.1 s |
| Coverage | `fvm flutter test --coverage`, then `awk -F: '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "%.2f%%\n",100*lh/lf}' coverage/lcov.info` | 93.55 % (TL re-computed: same) | 1.8 s |
| L4 E2E | `fvm flutter pub add 'dev:integration_test:{"sdk":"flutter"}'`; `fvm flutter test integration_test -d $UDID` | pass | **41 s cold** (Xcode build 31 s) / **13 s warm** |
| L5 In-test screenshots | `fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d $UDID`, with `binding.takeScreenshot('name')` and `integrationDriver(onScreenshot: …)` writing to `$SCREENSHOT_DIR` | 2 PNGs, 1206×2622 | 13 s |
| L5 Out-of-test screenshot | `fvm flutter build ios --simulator --debug`; `xcrun simctl install $UDID build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch $UDID <bundle-id>`; `xcrun simctl io $UDID screenshot out.png` | PNG with the real status bar | build 12 s |
| Simulator lifecycle | `UDID=$(xcrun simctl create mc-<task>-<role> "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-2)`; `xcrun simctl boot $UDID && xcrun simctl bootstatus $UDID -b`; teardown `xcrun simctl shutdown $UDID; xcrun simctl delete $UDID` | OK; boot about 19 s | — |
| Parallel | a second `simctl create` plus boot while the first is booted | both run | — |

## Gotchas (must-know for Engineers and Verifiers)
1. **Goldens use the Ahem font.** All text shows as black boxes, and the platform defaults to Android (so the AppBar title is left-aligned). Goldens still catch layout and colour regressions, but humans can't read them. Real fonts must be loaded in `test/flutter_test_config.dart` (UNVERIFIED; T-0005 owns it), and the iOS platform set explicitly.
2. **Stale golden diffs:** `test/failures/` isn't cleared on a passing run. Run `rm -rf test/failures` before tests.
3. **`xcrun simctl clone` fails on a booted device** (code 405). Always `simctl create` a fresh device.
4. **Wait for boot with `xcrun simctl bootstatus $UDID -b`**, not `sleep`.
5. **The first e2e run is about 3× slower** (cold Xcode build). Budget about 45 s cold and about 15 s warm per journey file.
6. **In-test screenshots show only the Flutter surface** (a blank strip where the status bar would be). `simctl` screenshots include the real status bar, but `simctl` can't tap, so it only covers the launch screen. Use in-test screenshots for every checkpoint after launch.
7. **One test file serves both modes:** `takeScreenshot` doesn't break a plain `flutter test integration_test` run.
8. **Parallel builds need separate `build/` folders.** Each agent runs in its own worktree, which gives it that. Two builds of the same folder at once is UNVERIFIED and not allowed.
9. **No code signing is needed** for simulator builds. CocoaPods picks up `integration_test` automatically.
10. **Without `.fvmrc`, `fvm flutter` silently uses the global SDK** (3.41.0). T-0003 must pin it.
11. **`sips -Z 1200` also enlarges smaller images.** Downscale only when the image is taller than 1200 px.

## Implications / actions
- ADR-0006 is confirmed as feasible. Its simulator-hygiene section is updated: create rather than clone, wait with `bootstatus`.
- T-0005 `tool/verify.sh`: `fvm dart format --output=none --set-exit-if-changed .`, `fvm flutter analyze`, `rm -rf test/failures`, `fvm flutter test --coverage`, then the awk coverage gate. Golden font loading is also in T-0005.
- T-0010 `tool/e2e_ios.sh`: create, boot and `bootstatus`, then `flutter drive` with `SCREENSHOT_DIR=documents/evidence/<task>/`, conditional `sips -Z 1200`, and `trap` teardown.
- Reference spike code (driver, e2e test) is in the TL scratchpad. It's ephemeral, so the essentials are captured above.
