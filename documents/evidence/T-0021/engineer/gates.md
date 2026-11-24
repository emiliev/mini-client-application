# T-0021 engineer gates (2026-11-24, branch `fleet/T-0021-app-shell` rebased on `c9dc283`)

All runs used `tool/bazelw --output_base=/tmp/mc-ob-T-0021-engineer …`.

| Gate | Result |
|---|---|
| `test //...` | exit 0; `Executed 24 out of 34 tests: 34 tests pass` (10 were cached) |
| `build --config=lint //...` | exit 0 (83 targets) |
| `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| `build --config=sim //app/mini_client:mini_client_ios` | exit 0 → `mini_client_ios.ipa` |
| `aquery 'mnemonic("FlutterAotMacho", deps(//... except attr(tags, "manual", //...)))'` | `No actions matched.` (R14: `bazel build //...` does no AOT; the app targets are `manual`) |
| `fvm dart format --output=none --set-exit-if-changed app utility/mc_ds_theme` | 0 changed |
| Simulator check `tool/checks/T-0021-AC3_AC6_sim.sh` | **PASS T-0021-AC6**, see [ac3-ac6-sim.md](ac3-ac6-sim.md) |

## AC → test
| AC | Test / evidence |
|---|---|
| AC1 | `//app/wiring/app_core:boot_test`: "T-0021-AC1 a failing root initializer shows the error and Retry succeeds on the second attempt" (the real root list plus a wiring that throws once), and "T-0021-AC1 a failed run is discarded …" (BootBloc) |
| AC2 | `boot_test`: "T-0021-AC2 boot taking longer than 10 s shows the timeout state with Retry" (fake clock: loading at 9 s, timeout at 11 s, Retry waits for the same run, task runs once) and "T-0021-AC2 a boot that finishes while the timeout shows is picked up by Retry" |
| AC3 | `ac3-openurl-warm.png`: `simctl openurl` reaches SpringBoard, which shows **Open in “Mini Client”?** over the running app. simctl can't tap it (F-0020), so the route itself isn't on screen. The Dart path is covered by AC4's second test |
| AC4 | `//app/mini_client:app_test`: "T-0021-AC4 a cold-start link held during boot …" (`defaultRouteName = miniclient://app/placeholder/7`, boot held by a Completer: no Router, `probe.builds` and `probe.redirects` empty; after boot `Placeholder detail 7` shows and `probe.beforeReady == 0`), and "T-0021-AC4 a link pushed while boot is held wins …" (the iOS `flutter/navigation` `pushRouteInformation` message during boot; after ready, links go to go_router). On device: `ac4-openurl-cold.png` shows the same system prompt (F-0020) |
| AC5 | `app_test`: "T-0021-AC5 with the same link and a failing first boot, Retry replays the link once and every root type is registered exactly once" (`links.takes == 1`, one router created, the placeholder built once, each root initializer ran once per attempt into a fresh container, and every root singleton resolves to attempt 2's instance) |
| AC6 | sim build plus `ac6-home.png` (home placeholder in Inter); the bundle check finds `packages/mc_ds_theme/Inter` in FontManifest.json, 4 Inter .ttf files and `assets/app_config.json` (env `dev`); the gates above |
