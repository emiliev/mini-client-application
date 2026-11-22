# F-0005: Bash signal traps: background jobs ignore SIGINT, traps wait for foreground children, redirects leak into traps

- **Date:** 2026-11-22
- **Author:** crew: Engineer (T-0012)
- **Type:** Library behaviour
- **Related:** T-0012, ADR-0006 §6, F-0004

## Summary
Four shell behaviours decide whether a simulator gets cleaned up when an e2e run is interrupted:
1. **In a non-interactive bash, a job started with `&` begins with SIGINT and SIGQUIT ignored, and a signal that was ignored on entry can't be trapped.** A script started in the background by another script (or by an agent harness) therefore never runs its `trap … INT`: `kill -INT` does nothing. SIGTERM isn't affected. To test SIGINT handling, start the job with job control on (`set -m; script & pid=$!; set +m`).
2. **Bash runs a trap only after the current foreground command exits.** If `kill -INT` or `kill -TERM` reaches only the script's pid (not the whole process group, as Ctrl-C in a terminal does), a script blocked in a foreground `flutter drive` waits for it to finish (up to a minute) before cleaning up. Run long children as `cmd & wait $!`: `wait` returns as soon as a trapped signal arrives, and the trap runs immediately.
3. **The trap then has to kill the child's whole process tree** (`fvm`, then `flutter`, `dart`, `xcodebuild`). Killing only `$!` leaves `flutter drive` running against a simulator that is being deleted. `tool/e2e_ios.sh` walks the tree with `pgrep -P` and sends TERM, then KILL after 5 s.
4. **A redirect on a function call also captures any trap that fires inside it.** `run_child cmd >>target.log 2>&1` redirects the shell's own stdout and stderr for as long as the function runs. A trap that fires during its `wait` (and the EXIT trap after `exit`) therefore writes into `target.log`. Put the redirect on the background command inside the function (`"$@" >>"$log" 2>&1 &`). The first T-0012 suite run caught this: cleanup worked, but its messages were in the target log instead of on the console.

Related, and useful for tests: `xcrun simctl --set <dir>` gives a **private device set**. Simulators created there don't show up in the default `xcrun simctl list`, can be booted (about 16 s), and are deleted with `xcrun simctl --set <dir> delete <udid>`, which also works on a booted device. The T-0012 suite runs `sim_cleanup.sh` against one so it can't delete another agent's live `mc-` simulator.

## Evidence
Probe script `t.sh`: `trap 'echo trapped; exit 130' INT; sleep 30 & wait $!; echo not-trapped`, started from `/bin/bash -c` (3.2.57):

| Start | `kill -INT $pid` after 1 s | Result |
|---|---|---|
| `bash t.sh & pid=$!` | still running | INT ignored. A later `kill -TERM` gives rc 143. |
| `set -m; bash t.sh & pid=$!; set +m` | exits | prints `trapped`, rc 130 |

`test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint` sends SIGINT 3 s into `flutter drive` and asserts: exit 130; the trap's messages on the script's own output and not in the target log (point 4); the simulator deleted; and no process left with `-d <udid>` in its arguments.

Device set probe: `xcrun simctl --set "$DS" create mc-T-0012-probe …` gave a UDID; `xcrun simctl list devices | grep -c probe` gave 0; boot plus `bootstatus -b` took 16 s; `delete` while booted gave rc 0.

## Implications / actions
- Any script that must clean up on a signal (e2e runners, future `tool/verify.sh` steps that boot simulators) should use the `cmd >>log 2>&1 & wait $!` pattern, with the redirect on the background command, and kill the whole child tree in its trap.
- Agents that need to stop a background e2e run should send **SIGTERM**, which always works, not SIGINT.
- Tests that touch simulators "globally", such as cleanup tools, should use `simctl --set <private dir>` so they can't interfere with parallel crew members.
