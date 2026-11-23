#!/bin/bash
# T-0014 AC1: install the Bazel-built app on a private simulator, screenshot, delete the simulator.
set -euo pipefail
REPO=/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a5c44fd531dc49825
E=$REPO/documents/evidence/T-0014/engineer
W=/private/tmp/claude-501/-Users-emililiev-orca-workspaces-mini-client-tang/d152dd30-eec6-4962-a3ba-bd2883014b3a/scratchpad/t0014/ipa
rm -rf "$W"; mkdir -p "$W"
unzip -q "$REPO/bazel-bin/spike/hello/hello_ios.ipa" -d "$W"
APP=$(ls -d "$W"/Payload/*.app)
UDID=$(xcrun simctl create mc-T-0014-engineer "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-2)
echo "UDID=$UDID"
cleanup() { xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; xcrun simctl delete "$UDID" && echo "SIMULATOR_DELETED $UDID"; }
trap cleanup EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
PID_LINE=$(xcrun simctl launch "$UDID" com.emiliev.miniclient.spike.hello)
echo "launch: $PID_LINE"
sleep 8
xcrun simctl io "$UDID" screenshot "$W/launch.png" >/dev/null 2>&1
H=$(sips -g pixelHeight "$W/launch.png" | awk '/pixelHeight/{print $2}')
if [[ "$H" -gt 1200 ]]; then sips -Z 1200 "$W/launch.png" --out "$E/ac1-launch-sim.png" >/dev/null; else cp "$W/launch.png" "$E/ac1-launch-sim.png"; fi
RUNNING=$(xcrun simctl spawn "$UDID" launchctl list | grep -c 'com.emiliev.miniclient.spike.hello' || true)
{
  echo "# T-0014-AC1 launch on a private simulator"
  echo "- simulator: mc-T-0014-engineer ($UDID), iPhone 17 Pro, iOS 26.2 (deleted after the run)"
  echo "- app: $(basename "$APP") from bazel-bin/spike/hello/hello_ios.ipa, bundle id com.emiliev.miniclient.spike.hello"
  echo "- simctl launch: $PID_LINE"
  echo "- launchctl entries for the app 8 s after launch: $RUNNING"
  echo "- screenshot: ac1-launch-sim.png (original height ${H}px)"
} > "$E/ac1-launch.md"
cat "$E/ac1-launch.md"
