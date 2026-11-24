# T-0021 engineer gates (2026-11-24, branch `fleet/T-0021-app-shell` rebased on `61373cc`; round 3, code-review fixes)

All runs used `tool/bazelw --output_base=/tmp/mc-ob-T-0021-engineer …`.

| Gate | Result |
|---|---|
| `test //...` | exit 0; `Executed 9 out of 39 tests: 39 tests pass` (the rest were cached) |
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
| AC1 | `//app/wiring/app_core:boot_test`: "T-0021-AC1 a failing root initializer shows the error and Retry succeeds on the second attempt"; "T-0021-AC1 BootBloc (a McBloc) discards a failed run …" (recorded to monitoring); "T-0021-AC1 a boot that fails after the timeout showed shows the error and records it to monitoring"; "T-0021-AC1 an unknown backend.scenario fails boot with a clear error" |
| AC2 | `boot_test`: "T-0021-AC2 boot taking longer than 10 s shows the timeout state, and Retry abandons the attempt and starts a fresh one" (fake clock: loading at 9 s, timeout at 11 s; the stale result is ignored); "T-0021-AC2 Retry escapes a never-completing root initializer: the hung mc_di run is abandoned and a fresh one boots (P-028)"; "T-0021-AC2 a boot that succeeds after the timeout showed goes to ready". `//utility/mc_di:di_container_test`: "T-0021-AC2 a fresh call succeeds after abandon, and the abandoned call never publishes and disposes what it registered" |
| AC3 (amended, F-0020) | (a) `//app/mini_client:app_test`: "T-0021-AC3 a miniclient://app/placeholder link delivered on the platform navigation channel to the running app shows that route" (and back returns home), and "T-0021-AC3 a link for another host or scheme shows home, not its path". `links_and_hooks_test`: "T-0021-AC3 an unreadable e2e start link file is ignored". (b) `ac3-e2e-link.png` (26.2) and `ios18-2/ac3-e2e-link.png` (18.2) both show *Placeholder detail 42*, reached through the e2e start link. `ac3-openurl-warm.png` (placeholder/43) and `ac4-openurl-cold.png` (both runtimes) show the iOS prompt *Open in “Mini Client”?*; the real `openurl` e2e is P-042 |
| AC4 | `app_test`: "T-0021-AC4 a cold-start link held during boot …" (no Router, 0 route builds and 0 redirects while boot is held; then *Placeholder detail 7*; `beforeReady == 0`) , "T-0021-AC4 a link pushed while boot is held wins …", and "T-0021-AC4 a link delivered between BootReady and the router's first frame is held and forwarded to go_router, not lost" (it fails when `PendingLinks` detaches before the frame; checked). `links_and_hooks_test`: "T-0021-AC4 normalise sends links for another host or scheme to /" |
| AC5 | `app_test`: "T-0021-AC5 … Retry replays the link once and every root type is registered exactly once" |
| AC6 | the gates above; `ac6-home.png` (26.2) and `ios18-2/ac6-home.png` (18.2) show the home placeholder in Inter with *Config: env=dev*. The bundle check finds `packages/mc_ds_theme/Inter`, 4 Inter files and `assets/app_config.json` |
