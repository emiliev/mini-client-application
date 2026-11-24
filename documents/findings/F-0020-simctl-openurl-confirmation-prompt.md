# F-0020: `simctl openurl` with a custom scheme shows "Open in …?" on iOS 26.2, and simctl cannot answer it

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0021)
- **Type:** Gotcha (e2e tooling)
- **Related:** T-0021-AC3 / AC4, plan 01 §4.4, R19, R29, [evidence](../evidence/T-0021/engineer/ac3-ac6-sim.md)

## Summary
On the iOS 26.2 simulator (Xcode 26.2), `xcrun simctl openurl <udid> miniclient://app/placeholder/42` doesn't deliver the link straight away. SpringBoard first shows a system alert, **Open in “Mini Client”?**, with Cancel and Open. This happens whether the app is frontmost (warm) or not running (cold), and it happens again on every call. `simctl` has no tap or key input, so a script can't confirm it. The link reaches the app only after someone taps Open.

Plan 01 §4.4 and P1-16 AC3 assumed `simctl openurl` is enough to drive a deep link in e2e. It isn't on this runtime.

## Evidence
- `ac3-openurl-warm.png`: the home placeholder, dimmed, under the alert.
- `ac4-openurl-cold.png`: the home screen with the alert (the app had been terminated first; `launchctl` shows no app process 10 s later).
- Both `openurl` calls exit 0. The bundle has `CFBundleURLSchemes = [miniclient]` and `FlutterDeepLinkingEnabled = true`, which is what lets SpringBoard name the app in the alert.

## What was tried (none worked without installing anything)
- Searching the 26.2 runtime for a SpringBoard default that skips the prompt. There is a `_handleTrustedOpenRequestForApplication` path, but simctl's request is untrusted, and no user default turns the prompt off.
- `uiopen` doesn't exist in the 26.2 runtime.
- AppleScript UI scripting of Simulator.app needs Accessibility permission for the terminal. That would mean a system prompt on the PO's machine, so it wasn't pursued.

## Options (TL decides)
1. **XCUITest springboard tap:** a tiny UI-test runner that calls `XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"].tap()` after `openurl`. This is what Detox and Maestro do. It needs an Xcode test bundle (P5 e2e harness).
2. **Patrol-style native automation** in the e2e journey (P5), which can tap system alerts.
3. **SimulatorKit HID injection** (what idb does) from a small Swift script. That uses a private API and is fragile.
4. Accept a one-time manual tap for the screenshot checkpoints until (1) or (2) exists.

The Dart side of the path, the engine's `pushRouteInformation` → `PendingLinks` / go_router, is covered by the T-0021-AC4 widget tests. They send the same `flutter/navigation` platform message that the iOS embedder sends.
