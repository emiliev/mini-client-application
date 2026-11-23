#!/bin/bash
# T-0014-AC1: build //spike/hello:hello_ios for the simulator, install and
# launch it on a private `mc-T-0014-<role>-<pid>` simulator, take a screenshot
# (at most 1200 px tall), and always delete the simulator.
#   tool/checks/T-0014-AC1_sim_launch.sh [--role engineer|verifier] [--out FILE]
# The screenshot is written next to FILE (ac1-launch-sim.png), or into a temp
# dir whose path is printed.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"
BUNDLE_ID=com.emiliev.miniclient.spike.hello
TMP="$(mktemp -d)"
SHOT_DIR="${OUT:+$(dirname "$OUT")}"; SHOT_DIR="${SHOT_DIR:-$TMP}"
UDID=""
cleanup() {
  if [[ -n "$UDID" ]]; then
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
    xcrun simctl delete "$UDID" >/dev/null 2>&1 && echo "SIMULATOR_DELETED $UDID" >&2
  fi
  [[ "$SHOT_DIR" == "$TMP" ]] || rm -rf "$TMP"
}
trap cleanup EXIT

"$BAZELW" build --config=sim //spike/hello:hello_ios > "$TMP/build.log" 2>&1; rc_build=$?
built=$(plain "$TMP/build.log" | grep -a -E 'Build completed|ERROR' | tail -1)
report "# T-0014-AC1: simulator build and launch" "" "- build: exit $rc_build ($built)"
[[ $rc_build -eq 0 ]] || finish T-0014-AC1 1
mkdir -p "$TMP/ipa"
# The app is built in a transitioned iOS configuration, so ask Bazel for the path.
IPA="$("$BAZELW" info execution_root 2>/dev/null)/$("$BAZELW" cquery --config=sim --output=files //spike/hello:hello_ios 2>/dev/null | grep '\.ipa$')"
unzip -q "$IPA" -d "$TMP/ipa" || { report "- no ipa at \`$IPA\`"; finish T-0014-AC1 1; }
APP=$(ls -d "$TMP"/ipa/Payload/*.app)
NAME="mc-T-0014-$ROLE-$$"
UDID=$(xcrun simctl create "$NAME" "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-2) || finish T-0014-AC1 1
xcrun simctl boot "$UDID" && xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
launch=$(xcrun simctl launch "$UDID" "$BUNDLE_ID" 2>&1); rc_launch=$?
sleep 8
running=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -c "$BUNDLE_ID" || true)
xcrun simctl io "$UDID" screenshot "$TMP/launch.png" >/dev/null 2>&1
H=$(sips -g pixelHeight "$TMP/launch.png" 2>/dev/null | awk '/pixelHeight/{print $2}')
if [[ "${H:-0}" -gt 1200 ]]; then sips -Z 1200 "$TMP/launch.png" --out "$SHOT_DIR/ac1-launch-sim.png" >/dev/null
else cp "$TMP/launch.png" "$SHOT_DIR/ac1-launch-sim.png"; fi
report "- simulator: \`$NAME\` ($UDID), iPhone 17 Pro, iOS 26.2; deleted on exit" \
  "- app: $(basename "$APP") from \`bazel-out/${IPA##*/bazel-out/}\`, bundle id \`$BUNDLE_ID\`" \
  "- \`simctl launch\`: exit $rc_launch ($launch)" \
  "- launchctl entries for the app 8 s after launch: $running" \
  "- screenshot: \`$SHOT_DIR/ac1-launch-sim.png\` (original height ${H:-?} px)"
ok=0
[[ $rc_launch -eq 0 && "$running" -ge 1 && -s "$SHOT_DIR/ac1-launch-sim.png" ]] && ok=1
finish T-0014-AC1 $([[ $ok -eq 1 ]] && echo 0 || echo 1)
