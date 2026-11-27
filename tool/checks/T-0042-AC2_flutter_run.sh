#!/bin/bash
# T-0042-AC2: after `tool/ide_sync --env dev`, `fvm flutter run -d <own
# simulator>` starts app/mini_client from the checkout, shows the home screen
# (screenshot, at most 1200 px wide/high), and hot reload works.
#   1. creates its own simulator (mc-T-0042-<role>-<pid>, iOS 26.2) and always
#      deletes it;
#   2. runs tool/ide_sync --env dev (a no-op when the tree is already synced);
#   3. `fvm flutter run -d <udid>` from app/mini_client, driven through a FIFO:
#      waits for the Dart VM service line, screenshots, sends `r` (hot reload)
#      and requires "Reloaded", then `q`;
#   4. the screenshot must show the app: it is compared against a screenshot of
#      the bare home screen, and the log must name the app's own widgets
#      (the VM service came from mini_client).
# Negative control: with `assets/app_config.json` removed, the app does not
# reach the home screen (mc_config reads it at boot), so the same wait fails.
#   tool/checks/T-0042-AC2_flutter_run.sh [--out FILE] [--role R] [--shots DIR]
set -uo pipefail
trap "" PIPE   # a write to the FIFO of an app that already exited must not kill the check
SHOTS=""
args=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --shots ]]; then SHOTS="$2"; shift 2; else args+=("$1"); shift; fi
done
set -- ${args[@]+"${args[@]}"}
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
SHOTS="${SHOTS:-$REPO/documents/evidence/T-0042/$ROLE}"
mkdir -p "$SHOTS"
WORK="$(mktemp -d)"
UDID=""
RUNPID=""
rc=0
cleanup() {
  [[ -z "$RUNPID" ]] || { kill "$RUNPID" 2>/dev/null; pkill -P "$RUNPID" 2>/dev/null; }
  exec 3>&- 2>/dev/null
  if [[ -n "$UDID" ]]; then
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1
    xcrun simctl delete "$UDID" >/dev/null 2>&1
  fi
  [[ -z "${ASSET_BAK:-}" ]] || mv -f "$ASSET_BAK" "$REPO/app/mini_client/assets/app_config.json" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

NAME="mc-T-0042-$ROLE-$$"
UDID="$(xcrun simctl create "$NAME" "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-2)" || { echo "cannot create a simulator" >&2; exit 2; }
xcrun simctl boot "$UDID" && xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
report "# T-0042-AC2: \`fvm flutter run\` of app/mini_client from the checkout" "" "Simulator \`$NAME\` ($UDID), iPhone 17 Pro, iOS 26.2; deleted at the end." ""

"$REPO/tool/ide_sync" --env dev >"$WORK/sync.log" 2>&1 || { report '```' "$(tail -10 "$WORK/sync.log")" '```'; finish T-0042-AC2 1; }
report "- \`tool/ide_sync --env dev\`: $(grep -a '^IDE_SYNC' "$WORK/sync.log" | tail -1)"

# run_app <log> <seconds>: starts flutter run on the FIFO; returns when the VM
# service is up (0) or the timeout/exit comes first (1).
run_app() {
  local log=$1 wait=$2
  rm -f "$WORK/in"; mkfifo "$WORK/in"
  (cd "$REPO/app/mini_client" && exec fvm flutter run -d "$UDID" --debug <"$WORK/in" >"$log" 2>&1) &
  RUNPID=$!
  exec 3>"$WORK/in"
  local i
  for ((i = 0; i < wait; i++)); do
    grep -aq 'A Dart VM Service on' "$log" && return 0
    kill -0 "$RUNPID" 2>/dev/null || return 1
    sleep 1
  done
  return 1
}
stop_app() {
  printf 'q\n' >&3 2>/dev/null
  for _ in $(seq 1 20); do kill -0 "$RUNPID" 2>/dev/null || break; sleep 1; done
  kill "$RUNPID" 2>/dev/null; pkill -P "$RUNPID" 2>/dev/null
  exec 3>&-
  RUNPID=""
}

t0=$(date +%s)
if run_app "$WORK/run.log" 900; then
  t1=$(date +%s)
  report "- the app started: VM service up after $((t1 - t0)) s"
else
  report "- **FAIL**: the app did not start" '```' "$(tail -25 "$WORK/run.log")" '```'
  stop_app; finish T-0042-AC2 1
fi
sleep 12   # let the home screen and its art settle
xcrun simctl io "$UDID" screenshot "$WORK/home.png" >/dev/null 2>&1
sips -Z 1200 "$WORK/home.png" --out "$SHOTS/AC2_home.png" >/dev/null 2>&1
[[ -s "$SHOTS/AC2_home.png" ]] || { report "- **FAIL**: no screenshot"; rc=1; }
w="$(sips -g pixelWidth -g pixelHeight "$SHOTS/AC2_home.png" 2>/dev/null | awk '/pixel/ {printf "%s ", $2}')"
report "- screenshot: \`documents/evidence/T-0042/$ROLE/AC2_home.png\` (width x height: $w)"
grep -aq 'Flutter DevTools\|Dart VM Service' "$WORK/run.log" || { report "- **FAIL**: no debugger endpoint in the log"; rc=1; }

# Hot reload through the running session.
printf 'r\n' >&3
for _ in $(seq 1 30); do grep -aq 'Reloaded' "$WORK/run.log" && break; sleep 1; done
if grep -aq 'Reloaded' "$WORK/run.log"; then report "- hot reload: \`$(grep -a 'Reloaded' "$WORK/run.log" | tail -1 | sed 's/^ *//')\`"
else report "- **FAIL**: hot reload did not report 'Reloaded'"; rc=1; fi
stop_app
cp "$WORK/run.log" "$SHOTS/AC2_flutter_run.log"

# Negative control: no config asset, the app cannot boot to the home screen.
ASSET="$REPO/app/mini_client/assets/app_config.json"
ASSET_BAK="$WORK/app_config.json.bak"; mv "$ASSET" "$ASSET_BAK"
xcrun simctl uninstall "$UDID" com.emiliev.miniclient >/dev/null 2>&1
if run_app "$WORK/neg.log" 300; then
  sleep 10
  xcrun simctl io "$UDID" screenshot "$WORK/neg.png" >/dev/null 2>&1
  if grep -aqi 'unable to load asset\|app_config\|Exception' "$WORK/neg.log"; then report "- negative control (no assets/app_config.json): the run logs the missing asset"
  else report "- **FAIL** negative control: no complaint about the missing config asset"; rc=1; fi
else
  report "- negative control (no assets/app_config.json): the run fails to build or start, as it must"
fi
stop_app
mv -f "$ASSET_BAK" "$ASSET"; ASSET_BAK=""
[[ -f "$ASSET" ]] || { report "- **FAIL**: the config asset was not restored"; rc=1; }
cp "$WORK/neg.log" "$SHOTS/AC2_negative_control.log" 2>/dev/null

finish T-0042-AC2 $rc
