#!/bin/bash
# T-0014-AC1 (Verifier): install the Bazel-built hello_ios.ipa on a private
# simulator, screenshot after launch and after one tap-free wait, then always
# delete the simulator.
#   ac1-launch.sh <path to hello_ios.ipa> <evidence dir> <scratch dir>
set -euo pipefail
IPA="$1"; E="$2"; W="$3/ipa"
rm -rf "$W"; mkdir -p "$W"
unzip -q "$IPA" -d "$W"
APP=$(ls -d "$W"/Payload/*.app)
UDID=$(xcrun simctl create mc-T-0014-verifier "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-2)
echo "UDID=$UDID"
cleanup() { xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; xcrun simctl delete "$UDID" && echo "SIMULATOR_DELETED $UDID"; }
trap cleanup EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
echo "launch: $(xcrun simctl launch "$UDID" com.emiliev.miniclient.spike.hello)"
sleep 15   # let first-boot system banners settle (F-0009 gotcha 5)
xcrun simctl io "$UDID" screenshot "$W/launch.png" >/dev/null 2>&1
H=$(sips -g pixelHeight "$W/launch.png" | awk '/pixelHeight/{print $2}')
echo "original height: $H"
sips -Z 1200 "$W/launch.png" --out "$E/ac1-launch-sim.png" >/dev/null
echo "app processes running: $(xcrun simctl spawn "$UDID" launchctl list | grep -c 'com.emiliev.miniclient.spike.hello' || true)"
