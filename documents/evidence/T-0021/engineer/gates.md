# T-0021 engineer gates (2026-11-24, branch `fleet/T-0021-app-shell` rebased on `61373cc`)

All runs used `tool/bazelw --output_base=/tmp/mc-ob-T-0021-engineer …`.

| Gate | Result |
|---|---|
| `test //...` | exit 0; `Executed 12 out of 39 tests: 39 tests pass` (the rest were cached) |
| `build --config=lint //...` | exit 0 (90 targets) |
| `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| `build --config=sim //app/mini_client:mini_client_ios` | exit 0 |
| `aquery 'mnemonic("FlutterAotMacho", deps(//... except attr(tags, "manual", //...)))'` | `No actions matched.` (R14) |
| `fvm dart format --output=none --set-exit-if-changed app utility/mc_ds_theme` | 0 changed |
| `tool/checks/T-0021-AC3_AC6_sim.sh`, iPhone 17 Pro / iOS 26.2 | **PASS** → [ac3-ac6-sim.md](ac3-ac6-sim.md) |
| same script, iPhone SE (3rd gen) / iOS 18.2 | **PASS** → [ios18-2/ac3-ac6-sim.md](ios18-2/ac3-ac6-sim.md) |

## AC → test / evidence
| AC | Test / evidence |
|---|---|
| AC1 | `//app/wiring/app_core:boot_test`: "T-0021-AC1 a failing root initializer shows the error and Retry succeeds on the second attempt" (the real root list plus a wiring that throws once) and "T-0021-AC1 BootBloc (a McBloc) discards a failed run …" (the failure is recorded to monitoring) |
| AC2 | `boot_test`: "T-0021-AC2 boot taking longer than 10 s shows the timeout state with Retry" (fake clock: loading at 9 s, timeout at 11 s; Retry waits for the same run, which runs once) and "T-0021-AC2 a boot that finishes while the timeout shows is picked up by Retry" |
| AC3 (amended, F-0020) | (a) `//app/mini_client:app_test`: "T-0021-AC3 a miniclient://app/placeholder link delivered on the platform navigation channel to the running app shows that route" (and back returns home). (b) `ac3-e2e-link.png` (26.2) and `ios18-2/ac3-e2e-link.png` (18.2) both show *Placeholder detail 42*, reached through the e2e start link. `ac3-openurl-warm.png` and `ac4-openurl-cold.png` (both runtimes) show the iOS prompt *Open in “Mini Client”?*; the real `openurl` e2e is P-042 |
| AC4 | `app_test`: "T-0021-AC4 a cold-start link held during boot …" (no Router, 0 route builds and 0 redirects while boot is held; then *Placeholder detail 7*; `beforeReady == 0`) and "T-0021-AC4 a link pushed while boot is held wins …" |
| AC5 | `app_test`: "T-0021-AC5 … Retry replays the link once and every root type is registered exactly once" |
| AC6 | the gates above; `ac6-home.png` (26.2) and `ios18-2/ac6-home.png` (18.2) show the home placeholder in Inter with *Config: env=dev*. The bundle check finds `packages/mc_ds_theme/Inter`, 4 Inter files and `assets/app_config.json` |
